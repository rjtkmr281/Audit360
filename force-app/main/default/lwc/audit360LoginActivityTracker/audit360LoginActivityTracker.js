import { LightningElement, track } from 'lwc';
import getLoginHistory from '@salesforce/apex/Audit360_LoginActivityController.getLoginHistory';
import getDashboardStats from '@salesforce/apex/Audit360_LoginActivityController.getDashboardStats';
import getSecurityAlerts from '@salesforce/apex/Audit360_LoginActivityController.getSecurityAlerts';
import getUserLoginHistory from '@salesforce/apex/Audit360_LoginActivityController.getUserLoginHistory';
import exportToCsv from '@salesforce/apex/Audit360_LoginActivityController.exportToCsv';

const DONUT_CIRCUMFERENCE = 2 * Math.PI * 50; // r=50

export default class Audit360_LoginActivityTracker extends LightningElement {

    // ── Active Tab ──────────────────────────────────────────────────────────
    @track activeTab = 'dashboard';
    @track isLoading = false;

    // ── Dashboard ───────────────────────────────────────────────────────────
    @track stats = {
        totalLogins: 0, successLogins: 0, failedLogins: 0,
        uniqueUsers: 0, todayLogins: 0,
        browserBreakdown: [], suspiciousIps: [], topUsers: []
    };

    // ── History Table ───────────────────────────────────────────────────────
    @track loginRecords = [];
    @track totalCount = 0;
    @track currentPage = 1;
    @track pageSize = '10';
    @track sortField = 'LoginTime';
    @track sortDir = 'desc';

    // ── Filters ─────────────────────────────────────────────────────────────
    @track searchKey = '';
    @track statusFilter = 'All';
    @track loginTypeFilter = 'All';
    @track browserFilter = 'All';
    @track dateRangeFilter = 'LAST30';
    _searchTimer;

    // ── Alerts ──────────────────────────────────────────────────────────────
    @track securityAlerts = [];

    // ── Drill-Down ──────────────────────────────────────────────────────────
    @track drillRecords = [];
    @track selectedUserId = null;
    @track selectedUserName = '';
    @track showDrillModal = false;
    @track drillModalUser = '';

    // ── Toast ────────────────────────────────────────────────────────────────
    @track showToast = false;
    @track toastMessage = '';
    @track toastIcon = 'utility:check';
    @track toastType = 'success';
    _toastTimer;

    // ── Lifecycle ────────────────────────────────────────────────────────────
    connectedCallback() {
        this.loadDashboard();
        this.loadAlerts();
        this.loadHistory();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DATA LOADING
    // ─────────────────────────────────────────────────────────────────────────

    async loadDashboard() {
        try {
            const raw = await getDashboardStats({ dateRangeFilter: this.dateRangeFilter });
            const maxBrowser = raw.browserBreakdown && raw.browserBreakdown.length
                ? raw.browserBreakdown[0].value : 1;
            const maxUser = raw.topUsers && raw.topUsers.length
                ? raw.topUsers[0].count : 1;

            this.stats = {
                ...raw,
                browserBreakdown: (raw.browserBreakdown || []).map(b => ({
                    ...b,
                    label: b.label || 'Unknown',
                    barStyle: `width:${Math.round((b.value / maxBrowser) * 100)}%`
                })),
                suspiciousIps: (raw.suspiciousIps || []).map((ip, i) => ({
                    ...ip, rank: i + 1
                })),
                topUsers: (raw.topUsers || []).map((u, i) => ({
                    ...u,
                    rank: i + 1,
                    initials: this.getInitials(u.userName),
                    barStyle: `width:${Math.round((u.count / maxUser) * 100)}%`
                }))
            };
        } catch (e) {
            this.showError('Failed to load dashboard: ' + this.extractMsg(e));
        }
    }

    async loadHistory() {
        this.isLoading = true;
        try {
            const result = await getLoginHistory({
                searchKey: this.searchKey,
                statusFilter: this.statusFilter,
                loginTypeFilter: this.loginTypeFilter,
                browserFilter: this.browserFilter,
                dateRangeFilter: this.dateRangeFilter,
                dateFrom: '',
                dateTo: '',
                sortField: this.sortField,
                sortDir: this.sortDir,
                pageSize: parseInt(this.pageSize, 10),
                pageNumber: this.currentPage
            });
            this.totalCount = result.totalCount;
            this.loginRecords = (result.records || []).map(r => this.enrichRow(r));
        } catch (e) {
            this.showError('Failed to load history: ' + this.extractMsg(e));
        } finally {
            this.isLoading = false;
        }
    }

    async loadAlerts() {
        try {
            const raw = await getSecurityAlerts();
            this.securityAlerts = (raw || []).map(a => ({
                ...a,
                cardClass: 'alert-card alert-card-' + a.severity.toLowerCase(),
                iconClass: 'alert-icon-wrap alert-icon-' + a.severity.toLowerCase(),
                severityClass: 'sev-badge sev-' + a.severity.toLowerCase()
            }));
        } catch (e) {
            console.error('Alert load error', e);
        }
    }

    async loadDrillDown(userId, userName) {
        this.isLoading = true;
        try {
            const raw = await getUserLoginHistory({ userId, limitSize: 50 });
            this.drillRecords = (raw || []).map(r => this.enrichRow(r));
            this.selectedUserId = userId;
            this.selectedUserName = userName;
        } catch (e) {
            this.showError('Failed to load user history');
        } finally {
            this.isLoading = false;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TAB NAVIGATION
    // ─────────────────────────────────────────────────────────────────────────

    showDashboard() { this.activeTab = 'dashboard'; }
    showHistory() { this.activeTab = 'history'; }
    showAlerts() { this.activeTab = 'alerts'; }
    showUsers() { this.activeTab = 'users'; this.selectedUserId = null; }

    get isDashboard() { return this.activeTab === 'dashboard'; }
    get isHistory() { return this.activeTab === 'history'; }
    get isAlerts() { return this.activeTab === 'alerts'; }
    get isUsers() { return this.activeTab === 'users'; }

    get tabDashboard() { return this.navCls('dashboard'); }
    get tabHistory() { return this.navCls('history'); }
    get tabAlerts() { return this.navCls('alerts'); }
    get tabUsers() { return this.navCls('users'); }

    navCls(tab) {
        return 'lg-nav-btn' + (this.activeTab === tab ? ' lg-nav-btn-active' : '');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FILTER HANDLERS
    // ─────────────────────────────────────────────────────────────────────────

    handleSearch(e) {
        clearTimeout(this._searchTimer);
        const val = e.target.value;
        this._searchTimer = setTimeout(() => {
            this.searchKey = val;
            this.currentPage = 1;
            this.loadHistory();
        }, 350);
    }

    handleStatusFilter(e) { this.statusFilter = e.detail.value; this.reset(); }
    handleLoginTypeFilter(e) { this.loginTypeFilter = e.detail.value; this.reset(); }
    handleBrowserFilter(e) { this.browserFilter = e.detail.value; this.reset(); }
    handlePageSize(e) { this.pageSize = e.detail.value; this.currentPage = 1; this.loadHistory(); }

    handleDateRange(e) {
        this.dateRangeFilter = e.detail.value;
        this.reset();
        this.loadDashboard();
    }

    handleSort(e) {
        const field = e.currentTarget.dataset.field;
        if (this.sortField === field) {
            this.sortDir = this.sortDir === 'desc' ? 'asc' : 'desc';
        } else {
            this.sortField = field;
            this.sortDir = 'desc';
        }
        this.loadHistory();
    }

    clearFilters() {
        this.searchKey = '';
        this.statusFilter = 'All';
        this.loginTypeFilter = 'All';
        this.browserFilter = 'All';
        this.reset();
    }

    reset() { this.currentPage = 1; this.loadHistory(); }

    // ─────────────────────────────────────────────────────────────────────────
    // PAGINATION
    // ─────────────────────────────────────────────────────────────────────────

    handlePrev() { if (!this.isFirstPage) { this.currentPage--; this.loadHistory(); } }
    handleNext() { if (!this.isLastPage) { this.currentPage++; this.loadHistory(); } }
    handlePageJump(e) {
        const pg = parseInt(e.target.dataset.page, 10);
        if (pg !== this.currentPage) { this.currentPage = pg; this.loadHistory(); }
    }

    get totalPages() { return Math.max(1, Math.ceil(this.totalCount / parseInt(this.pageSize, 10))); }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage >= this.totalPages; }
    get startRecord() { return this.totalCount === 0 ? 0 : (this.currentPage - 1) * parseInt(this.pageSize, 10) + 1; }
    get endRecord() { return Math.min(this.currentPage * parseInt(this.pageSize, 10), this.totalCount); }
    get hasRecords() { return this.loginRecords && this.loginRecords.length > 0; }

    get pageButtons() {
        const pages = [];
        const total = this.totalPages;
        const cur = this.currentPage;
        let start = Math.max(1, cur - 2);
        let end = Math.min(total, start + 4);
        start = Math.max(1, end - 4);
        for (let i = start; i <= end; i++) {
            pages.push({ num: i, cls: 'pager-num' + (i === cur ? ' pager-num-active' : '') });
        }
        return pages;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // DRILL-DOWN
    // ─────────────────────────────────────────────────────────────────────────

    handleUserDrill(e) {
        const userId = e.currentTarget.dataset.userid;
        const userName = e.currentTarget.dataset.username || '';
        this.drillModalUser = userName;

        if (this.activeTab === 'users') {
            // Full page drill in Users tab
            const user = this.stats.topUsers.find(u => u.userId === userId);
            this.loadDrillDown(userId, user ? user.userName : 'User');
        } else {
            // Modal drill from other tabs
            this.showDrillModal = true;
            this.loadDrillDown(userId, userName).then(() => { });
        }
    }

    closeDrillModal() { this.showDrillModal = false; this.drillRecords = []; }
    stopProp(e) { e.stopPropagation(); }
    clearDrill() { this.selectedUserId = null; this.drillRecords = []; }

    // ─────────────────────────────────────────────────────────────────────────
    // EXPORT CSV
    // ─────────────────────────────────────────────────────────────────────────
    @track showModal = false;
    handleCloseModal() {
        this.showModal = false;
    }
    async handleExport() {
        if (!this.showModal) {
            this.showModal = true;
        } else {
            this.isLoading = true;
            try {
                const csv = await exportToCsv({
                    searchKey: this.searchKey,
                    statusFilter: this.statusFilter,
                    loginTypeFilter: this.loginTypeFilter,
                    dateRangeFilter: this.dateRangeFilter,
                    dateFrom: '',
                    dateTo: ''
                });
                const blob = new Blob([csv], { type: 'text/csv' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = 'LoginGuard_Export_' + new Date().toISOString().slice(0, 10) + '.csv';
                a.click();
                URL.revokeObjectURL(url);
                this.showSuccess('Export downloaded successfully!');
            } catch (e) {
                this.showError('Export failed: ' + this.extractMsg(e));
            } finally {
                this.isLoading = false;
            }
        }
    }

    handleRefresh() {
        this.loadDashboard();
        this.loadAlerts();
        this.loadHistory();
        this.showSuccess('Data refreshed!');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // COMPUTED GETTERS
    // ─────────────────────────────────────────────────────────────────────────

    get successRate() {
        if (!this.stats.totalLogins) return 0;
        return Math.round((this.stats.successLogins / this.stats.totalLogins) * 100);
    }

    get donutSuccessStyle() {
        const pct = this.successRate / 100;
        const dash = pct * DONUT_CIRCUMFERENCE;
        return `stroke-dasharray:${dash} ${DONUT_CIRCUMFERENCE};stroke-dashoffset:0`;
    }

    get donutFailedStyle() {
        const sp = (this.successRate / 100) * DONUT_CIRCUMFERENCE;
        const fp = ((100 - this.successRate) / 100) * DONUT_CIRCUMFERENCE;
        return `stroke-dasharray:${fp} ${DONUT_CIRCUMFERENCE};stroke-dashoffset:-${sp}`;
    }

    get hasAlerts() { return this.securityAlerts && this.securityAlerts.length > 0; }
    get alertCount() { return this.securityAlerts.length || null; }
    get hasIps() { return this.stats.suspiciousIps && this.stats.suspiciousIps.length > 0; }

    get sortArrow() { return this.sortDir === 'desc' ? '↓' : '↑'; }
    get sortByTime() { return this.sortField === 'LoginTime'; }
    get sortByUser() { return this.sortField === 'User.Name'; }

    get hasActiveFilters() {
        return this.searchKey || this.statusFilter !== 'All' ||
            this.loginTypeFilter !== 'All' || this.browserFilter !== 'All';
    }

    get toastClass() {
        return 'lg-toast lg-toast-' + this.toastType;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PICKLIST OPTIONS
    // ─────────────────────────────────────────────────────────────────────────

    get dateRangeOptions() {
        return [
            { label: 'Today', value: 'TODAY' },
            { label: 'Last 7 Days', value: 'LAST7' },
            { label: 'Last 30 Days', value: 'LAST30' },
            { label: 'Last 90 Days', value: 'LAST90' },
        ];
    }

    get statusOptions() {
        return [
            { label: 'All Statuses', value: 'All' },
            { label: '✓ Success', value: 'Success' },
            { label: '✕ Failed', value: 'Failed' },
        ];
    }

    get loginTypeOptions() {
        return [
            { label: 'All Login Types', value: 'All' },
            { label: 'SAML SSO', value: 'SAML Sfdc Initiated SSO' },
            { label: 'Remote Access 2.0', value: 'Remote Access 2.0' },
            { label: 'Application', value: 'Application' },
            { label: 'Other Apex API', value: 'Other Apex API' },
        ];
    }

    get browserOptions() {
        return [
            { label: 'All Browsers', value: 'All' },
            { label: 'Chrome', value: 'Chrome' },
            { label: 'Firefox', value: 'Firefox' },
            { label: 'Safari', value: 'Safari' },
            { label: 'Edge', value: 'Edge' },
            { label: 'Unknown', value: 'Unknown' },
        ];
    }

    get pageSizeOptions() {
        return [
            { label: '10 / page', value: '10' },
            { label: '25 / page', value: '25' },
            { label: '50 / page', value: '50' },
            { label: '100 / page', value: '100' },
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RECORD ENRICHMENT
    // ─────────────────────────────────────────────────────────────────────────

    enrichRow(r) {
        const dt = r.loginTime ? new Date(r.loginTime) : null;
        return {
            ...r,
            initials: this.getInitials(r.userName),
            avatarClass: 'user-avatar user-avatar-' + this.getAvatarColor(r.userName),
            loginDate: dt ? dt.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : '—',
            loginTimeStr: dt ? dt.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) : '—',
            statusClass: r.status === 'Success' ? 'status-pill status-success' : 'status-pill status-failed',
            browserIcon: this.getBrowserIcon(r.browser),
            profileName: r.profileName || '—',
            roleName: r.roleName || '',
            browser: r.browser || 'Unknown',
            platform: r.platform || 'Unknown',
            sourceIp: r.sourceIp || '—',
        };
    }

    getInitials(name) {
        if (!name) return '?';
        const parts = name.split(' ');
        return parts.length >= 2
            ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
            : name[0].toUpperCase();
    }

    getAvatarColor(name) {
        const colors = ['blue', 'green', 'purple', 'amber', 'teal', 'rose'];
        if (!name) return 'blue';
        return colors[name.charCodeAt(0) % colors.length];
    }

    getBrowserIcon(browser) {
        if (!browser) return 'utility:world';
        const b = browser.toLowerCase();
        if (b.includes('chrome')) return 'utility:world';
        if (b.includes('firefox')) return 'utility:world';
        if (b.includes('safari')) return 'utility:world';
        if (b.includes('edge')) return 'utility:world';
        return 'utility:world';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TOAST
    // ─────────────────────────────────────────────────────────────────────────

    showSuccess(msg) { this.toast(msg, 'success', 'utility:check'); }
    showError(msg) { this.toast(msg, 'error', 'utility:error'); }

    toast(msg, type, icon) {
        clearTimeout(this._toastTimer);
        this.toastMessage = msg;
        this.toastType = type;
        this.toastIcon = icon;
        this.showToast = true;
        this._toastTimer = setTimeout(() => { this.showToast = false; }, 3500);
    }

    extractMsg(e) { return e && e.body ? e.body.message : (e.message || 'Unknown error'); }
}