import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import querySetupAudit from '@salesforce/apex/Audit360_QueryController.querySetupAudit';
import generateCSV from '@salesforce/apex/Audit360_ExportController.generateCSV';

const PAGE_SIZE = 8;
const REFRESH_MS = 60_000;
const DEBOUNCE_MS = 300;

const SECTIONS = [
    'All Sections', 'Manage Users', 'Email Administration',
    'Flows', 'Validation Rules', 'Groups'
];

function scoreRisk(action = '', section = '', createdDate) {
    const a = action.toLowerCase();
    if (a.includes('suorgadminlogin')) return 'Critical';
    if (a.includes('sendemailaccesscontrol')) return 'Critical';
    if (a.includes('deactivateduser')) return 'Critical';
    if (a.includes('permsetunassign'))
        return (a.includes('bulk') || a.includes('20+')) ? 'Critical' : 'High';
    if (a.includes('dkimrotation') || section === 'Email Administration') return 'High';
    if (a.includes('deactivatedinteractiondefversion')) return 'Medium';
    if (a.includes('changedvalidationactive')) return 'Medium';
    if (a.includes('permsetassign') || a.includes('groupmembership')) return 'Low';
    const h = createdDate ? new Date(createdDate).getUTCHours() : 12;
    return (h < 9 || h >= 17) ? 'Medium' : 'Low';
}
/* ── CSS class maps ──────────────────────────────────── */
const SECTION_TAG = {
    'Email Administration': 'stag st-email',
    'Manage Users': 'stag st-users',
    'Flows': 'stag st-flows',
    'Validation Rules': 'stag st-validation',
    'Groups': 'stag st-groups',
};
const RISK_BADGE = {
    Critical: 'badge b-critical',
    High: 'badge b-high',
    Medium: 'badge b-medium',
    Low: 'badge b-low',
};
export default class Audit360_SetupAudit extends LightningElement {

    @track _rawData = [];
    @track _filtered = [];
    @track activeSection = 'All Sections';
    @track searchTerm = '';
    @track currentPage = 0;
    @track showPanel = false;
    @track selectedEvent = null;
    @track kpiList = [];

    _wiredResult;
    _refreshTimer;
    _debounceTimer;

    @wire(querySetupAudit)
    wiredAudit(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this._rawData = data.map(r => this._decorate(r));
            this.kpiList = [
                {
                    id: 1,
                    number: this._rawData.filter(r => r.Section === 'Email Administration' && ['Critical', 'High'].includes(r.riskLevel)).length,
                    label: 'Email Administration',
                    subject: 'DKIM, access',
                    color: 'kpiGreen'
                },
                {
                    id: 2,
                    number: this._rawData.length.toLocaleString(),
                    label: 'Total events',
                    subject: 'last 30 days',
                    color: 'kpiBlue'
                },
                {
                    id: 3,
                    number: this._rawData.filter(r => r.riskLevel === 'High').length,
                    label: 'High',
                    subject: 'review now',
                    color: 'kpiOrange'
                },
                {
                    id: 4,
                    number: this._rawData.filter(r => r.riskLevel === 'Critical').length,
                    label: 'Critical',
                    subject: 'needs action',
                    color: 'kpiRed'
                }
            ];
            this._applyFilters();
        }
        if (error) console.error('[Audit360]', error);
    }
    connectedCallback() {
        this._refreshTimer = setInterval(
            () => refreshApex(this._wiredResult),
            REFRESH_MS
        );
    }
    disconnectedCallback() {
        clearInterval(this._refreshTimer);
        clearTimeout(this._debounceTimer);
    }
    get kpiTotal() { return this._rawData.length.toLocaleString(); }
    get kpiCritical() { return this._rawData.filter(r => r.riskLevel === 'Critical').length; }
    get kpiHigh() { return this._rawData.filter(r => r.riskLevel === 'High').length; }
    get kpiEmailAdmin() { return this._rawData.filter(r => r.Section === 'Email Administration' && ['Critical', 'High'].includes(r.riskLevel)).length; }
    get sectionChips() {
        return SECTIONS.map(s => ({
            label: s,
            cssClass: s === this.activeSection ? 'chip chip-active' : 'chip',
        }));
    }
    /* ── Pagination ──────────────────────────────────── */
    get pagedRows() { return this._filtered.slice(this.currentPage * PAGE_SIZE, (this.currentPage + 1) * PAGE_SIZE); }
    get hasRows() { return this._filtered.length > 0; }
    get isFirstPage() { return this.currentPage === 0; }
    get isLastPage() { return (this.currentPage + 1) * PAGE_SIZE >= this._filtered.length; }
    get filteredCount() { return this._filtered.length; }
    get pageInfo() {
        const tot = this._filtered.length;
        const start = this.currentPage * PAGE_SIZE + 1;
        const end = Math.min((this.currentPage + 1) * PAGE_SIZE, tot);
        return `Page ${this.currentPage + 1} of ${Math.max(1, Math.ceil(tot / PAGE_SIZE))}  (${start}–${end} of ${tot})`;
    }
    get statusMsg() {
        const tot = this._filtered.length;
        const end = Math.min((this.currentPage + 1) * PAGE_SIZE, tot);
        return `Showing ${end} of ${tot} events · Click any row to expand · Auto-refresh every 60s`;
    }
    handleChipClick(event) {
        this.activeSection = event.currentTarget.dataset.section;
        this.currentPage = 0;
        this._applyFilters();
    }
    handleSearch(event) {
        clearTimeout(this._debounceTimer);
        const val = event.target.value;
        this._debounceTimer = setTimeout(() => {
            this.searchTerm = val;
            this.currentPage = 0;
            this._applyFilters();
        }, DEBOUNCE_MS);
    }
    handleRowClick(event) { this._openPanel(event.currentTarget.dataset.id); }
    handleViewClick(event) { event.stopPropagation(); this._openPanel(event.currentTarget.dataset.id); }
    handleOverlayClick(event) { if (event.target === event.currentTarget) this.showPanel = false; }
    closePanel() { this.showPanel = false; }
    stopProp(event) { event.stopPropagation(); }
    handlePrev() { if (!this.isFirstPage) this.currentPage--; }
    handleNext() {
        if (!this.showModal) {
            this.showModal = true;
        } else {
            if (!this.isLastPage) this.currentPage++;
        }

    }
    @track showModal = false;
    handleCloseModal() {
        this.showModal = false;
    }
    handleCsvExport() {

        if (!this.showModal) {
            this.showModal = true;
        } else {
            this.showModal = false;
            const request = {
                section: this.activeSection == 'All Sections' ? null : this.activeSection,
                searchTerm: this.searchTerm || null,
                maxRows: 10000,
            };
            generateCSV({ request })
                .then(csv => {
                    const bom = '\uFEFF';   // UTF-8 BOM for Excel
                    const blob = new Blob([bom + csv], { type: 'text/csv;charset=utf-8' });
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = `audit360_${this._filtered.length}_events.csv`;
                    a.click();
                    URL.revokeObjectURL(url);
                })
                .catch(err => console.error('[Audit360 CSV]', err));
        }
    }

    _applyFilters() {
        const q = this.searchTerm.toLowerCase().trim();
        const sec = this.activeSection;
        this._filtered = this._rawData.filter(r => {
            const sMatch = sec === 'All Sections' || r.Section === sec;
            const qMatch = !q
                || r.Display?.toLowerCase().includes(q)
                || r.Action?.toLowerCase().includes(q)
                || r.Section?.toLowerCase().includes(q)
                // FIX 2: search by username too
                || r.userName?.toLowerCase().includes(q);
            return sMatch && qMatch;
        });
    }

    _decorate(row) {
        const risk = scoreRisk(row.Action, row.Section, row.CreatedDate);
        return {
            ...row,
            riskLevel: risk,
            badgeClass: RISK_BADGE[risk] || 'badge b-low',
            sectionTagClass: SECTION_TAG[row.Section] || 'stag st-users',
            formattedDate: this._fmtDate(row.CreatedDate),
            formattedTime: this._fmtTime(row.CreatedDate),
            userName: row.createdByName || row.CreatedById || 'Unknown',
        };
    }
    _fmtDate(iso) {
        if (!iso) return '';
        return new Date(iso).toLocaleDateString('en-US', {
            month: 'short', day: 'numeric', year: 'numeric'
        });
    }
    _fmtTime(iso) {
        if (!iso) return '';
        const d = new Date(iso);
        return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }
    _openPanel(id) {
        this.selectedEvent = this._filtered.find(r => r.Id === id) || null;
        this.showPanel = !!this.selectedEvent;
    }
}