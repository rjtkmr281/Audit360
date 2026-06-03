import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getInitialData from '@salesforce/apex/Audit360_FieldHistoryController.getInitialData';
import getStatsSummary from '@salesforce/apex/Audit360_FieldHistoryController.getStatsSummary';
import getTrackedFieldsForObject from '@salesforce/apex/Audit360_FieldHistoryController.getTrackedFieldsForObject';
import getFieldHistory from '@salesforce/apex/Audit360_FieldHistoryController.getFieldHistory';
import getTrackingConfigLog from '@salesforce/apex/Audit360_FieldHistoryController.getTrackingConfigLog';
import exportFieldHistoryCsv from '@salesforce/apex/Audit360_FieldHistoryController.exportFieldHistoryCsv';

export default class Audit360FieldHistoryTracker extends LightningElement {

    // ── Stats ──────────────────────────────────────────────────────────────
    @track caseChanges    = '—';
    @track accountChanges = '—';
    @track contactChanges = '—';
    @track objectsTracked = '—';

    // ── Filters ────────────────────────────────────────────────────────────
    @track selectedObject    = 'Case';
    @track selectedField     = 'All fields';
    @track selectedDateRange = 'Last 7 days';

    @track showObjectDropdown   = false;
    @track showFieldDropdown    = false;
    @track showDateDropdown     = false;

    // ── Operator picklist — client-side only, zero Apex calls ──────────────
    @track selectedOperator     = 'Equal';
    @track showOperatorDropdown = false;
    operatorOptions = ['Equal', 'Greater Than', 'Less Than'];

    // ── Search / debounce ─────────────────────────────────────────────────
    @track searchValue = '';
    _debounceTimer = null;
    DEBOUNCE_DELAY = 400;

    // ── Dropdown options ───────────────────────────────────────────────────
    @track objectOptions = [];
    @track fieldOptions  = ['All fields'];
    dateOptions = ['Last 7 days', 'Last 30 days', 'Last 90 days', 'This Year'];

    // ── Table / Config data ────────────────────────────────────────────────
    @track filteredHistory   = [];
    @track trackingConfigLog = [];
    @track isLoading         = false;
    @track currentPage       = 1;
    @track showModal         = false;
    pageSize = 10;

    // ──────────────────────────────────────────────────────────────────────
    // Computed getters
    // ──────────────────────────────────────────────────────────────────────

    get isFieldSelected() {
        return this.selectedField !== 'All fields';
    }

    get isSearchDisabled() {
        return this.selectedField === 'All fields';
    }

    get searchInputClass() {
        return this.isSearchDisabled
            ? 'search-input search-input-disabled'
            : 'search-input';
    }

    get searchInputTitle() {
        return this.isSearchDisabled
            ? 'Select a specific field to enable search'
            : 'Filter by field value';
    }

    // ── displayedHistory ─────────────────────────────────────────────────
    get displayedHistory() {
        let records = this.filteredHistory;
        if (this.isFieldSelected && this.selectedOperator !== 'Equal' && this.searchValue) {
            records = this._applyOperatorFilter(records);
        }
        if (this.searchValue && !this.isSearchDisabled && this.selectedOperator === 'Equal') {
            const term = this.searchValue.toLowerCase();
            records = records.filter(rec =>
                (rec.newValueDisplay && rec.newValueDisplay.toLowerCase().includes(term)) ||
                (rec.oldValueDisplay && rec.oldValueDisplay.toLowerCase().includes(term))
            );
        }

        return records;
    }

    // ──────────────────────────────────────────────────────────────────────
    // Operator filter — pure JS, reads already-loaded filteredHistory
    // ──────────────────────────────────────────────────────────────────────

    _applyOperatorFilter(records) {
        if (!records || records.length === 0) return records;

        const sample = records.find(r => r.newValueDisplay && r.newValueDisplay !== '—');

        if (!sample) {
            this._showTypeError(
                `No new values found for "${this.selectedField}". ` +
                `Cannot apply Greater Than / Less Than.`
            );
            return records;
        }

        const compareValue = this.searchValue ? this.searchValue.trim() : '';
        if (!compareValue) return records;

        const detectedType = this._detectType(compareValue);

        if (detectedType === 'text' || detectedType === 'boolean') {
            this._showTypeError(
                `"${compareValue}" is a ${detectedType} value. ` +
                `Greater Than and Less Than only work with numbers or dates.`
            );
            return records;
        }

        const isGreater = this.selectedOperator === 'Greater Than';

        return records.filter(rec => {
            const val = rec.newValueDisplay;
            if (!val || val === '—') return false;

            if (detectedType === 'number') {
                const num = parseFloat(val.replace(/,/g, ''));
                const ref = parseFloat(compareValue.replace(/,/g, ''));
                if (isNaN(num) || isNaN(ref)) return false;
                return isGreater ? num > ref : num < ref;
            }

            if (detectedType === 'date') {
                const d   = Date.parse(val);
                const ref = Date.parse(compareValue);
                if (isNaN(d) || isNaN(ref)) return false;
                return isGreater ? d > ref : d < ref;
            }

            return true;
        });
    }

    // ── Detect type from a raw value string ──────────────────────────────
    _detectType(value) {
        if (!value || value === '—') return 'text';
        const v = value.trim();
        if (/^(true|false|yes|no)$/i.test(v)) return 'boolean';
        if (/^-?[\d,]+(\.\d+)?$/.test(v)) return 'number';
        if (
            /^\d{4}-\d{2}-\d{2}/.test(v) ||
            /^\d{1,2}\/\d{1,2}\/\d{4}/.test(v) ||
            (!isNaN(Date.parse(v)) && isNaN(Number(v)))
        ) return 'date';
        return 'text';
    }

    // ── Warning toast for type mismatch ───────────────────────────────────
    _showTypeError(message) {
        this.dispatchEvent(new ShowToastEvent({
            title:   'Operator Not Applicable',
            message: message,
            variant: 'warning',
            mode:    'dismissible'
        }));
        this.selectedOperator = 'Equal';
    }

    get hasRecords()         { return this.displayedHistory.length > 0; }
    get hasTrackingConfig()  { return this.trackingConfigLog.length > 0; }
    get totalRecords()       { return this.displayedHistory.length; }
    get totalPages()         { return Math.max(Math.ceil(this.totalRecords / this.pageSize), 1); }
    get normalizedCurrentPage() { return Math.min(this.currentPage, this.totalPages); }
    get isFirstPage()        { return this.normalizedCurrentPage <= 1; }
    get isLastPage()         { return this.normalizedCurrentPage >= this.totalPages; }
    get showPagination()     { return this.totalRecords > this.pageSize; }

    get paginationLabel() {
        if (!this.hasRecords) return '0 records';
        const start = ((this.normalizedCurrentPage - 1) * this.pageSize) + 1;
        const end   = Math.min(start + this.pageSize - 1, this.totalRecords);
        return `${start}-${end} of ${this.totalRecords}`;
    }

    get paginatedHistory() {
        const start = (this.normalizedCurrentPage - 1) * this.pageSize;
        return this.displayedHistory.slice(start, start + this.pageSize);
    }

    get kpiList() {
        const dateLabel = (this.selectedDateRange || 'selected range').toLowerCase();
        return [
            { id: 'caseChanges',    number: this.caseChanges,    label: 'Case changes',    subject: dateLabel,          color: 'kpiGreen'  },
            { id: 'accountChanges', number: this.accountChanges, label: 'Account changes', subject: dateLabel,          color: 'kpiBlue'   },
            { id: 'contactChanges', number: this.contactChanges, label: 'Contact changes', subject: dateLabel,          color: 'kpiBlue'   },
            { id: 'objectsTracked', number: this.objectsTracked, label: 'Objects tracked', subject: 'objects active',   color: 'kpiOrange' }
        ];
    }

    // ──────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ──────────────────────────────────────────────────────────────────────

    connectedCallback() {
        this.initComponent();
        this._boundHandleOutsideClick = this._handleOutsideClick.bind(this);
        window.addEventListener('click', this._boundHandleOutsideClick);
    }

    disconnectedCallback() {
        if (this._debounceTimer) clearTimeout(this._debounceTimer);
        if (this._boundHandleOutsideClick) {
            window.removeEventListener('click', this._boundHandleOutsideClick);
            this._boundHandleOutsideClick = null;
        }
    }

    _handleOutsideClick(event) {
        if (!this.template || !this.template.contains(event.target)) {
            this.showObjectDropdown   = false;
            this.showFieldDropdown    = false;
            this.showDateDropdown     = false;
            this.showOperatorDropdown = false;
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // initComponent
    // ──────────────────────────────────────────────────────────────────────

    async initComponent() {
        this.isLoading = true;
        try {
            const data = await getInitialData({
                objectName: this.selectedObject,
                fieldName:  null,
                dateRange:  this.selectedDateRange
            });

            this.objectOptions  = data?.objectOptions?.length > 0
                ? data.objectOptions
                : ['Case', 'Account', 'Contact'];
            this.selectedObject  = data?.selectedObject || this.objectOptions[0];
            this.fieldOptions    = ['All fields', ...(data?.fieldOptions || [])];
            this.selectedField   = 'All fields';
            this.selectedOperator = 'Equal';
            this.applyHistory(data?.history);

        } catch (error) {
            this.handleError(error);
        } finally {
            this.isLoading = false;
        }

        setTimeout(() => {
            this.loadStatsBackground();
            this.loadTrackingConfig();
        }, 0);
    }

    async loadStatsBackground() {
        try {
            const result = await getStatsSummary({ dateRange: this.selectedDateRange });
            this.applyStats(result);
        } catch (error) {
            this.handleError(error);
        }
    }

    async loadTrackingConfig() {
        try {
            const result = await getTrackingConfigLog();
            this.trackingConfigLog = (result || []).map((cfg, idx) => {
                const active = cfg.isActive !== undefined ? cfg.isActive : cfg.active;
                return {
                    id:          cfg.id || String(idx),
                    objectName:  cfg.objectName || cfg.name || cfg.objectName || '',
                    fields:      cfg.fields || cfg.fieldNames || cfg.fields || '',
                    status:      active !== false ? 'ON' : 'OFF',
                    statusClass: active !== false ? 'status-badge on' : 'status-badge off',
                    date:        cfg.dateIs || cfg.date || cfg.dateString || ''
                };
            });
        } catch (error) {
            this.trackingConfigLog = [];
            this.handleError(error);
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Dropdown toggles — each closes the others
    // ──────────────────────────────────────────────────────────────────────

    toggleObjectDropdown(event) {
        event.stopPropagation();
        this.showObjectDropdown   = !this.showObjectDropdown;
        this.showFieldDropdown    = false;
        this.showDateDropdown     = false;
        this.showOperatorDropdown = false;
    }

    toggleFieldDropdown(event) {
        event.stopPropagation();
        this.showFieldDropdown    = !this.showFieldDropdown;
        this.showObjectDropdown   = false;
        this.showDateDropdown     = false;
        this.showOperatorDropdown = false;
    }

    toggleDateDropdown(event) {
        event.stopPropagation();
        this.showDateDropdown     = !this.showDateDropdown;
        this.showObjectDropdown   = false;
        this.showFieldDropdown    = false;
        this.showOperatorDropdown = false;
    }

    toggleOperatorDropdown(event) {
        event.stopPropagation();
        this.showOperatorDropdown = !this.showOperatorDropdown;
        this.showObjectDropdown   = false;
        this.showFieldDropdown    = false;
        this.showDateDropdown     = false;
    }

    // ──────────────────────────────────────────────────────────────────────
    // Selection handlers
    // ──────────────────────────────────────────────────────────────────────

    async selectObject(event) {
        event.stopPropagation();
        const chosenObject = (event.currentTarget.dataset.value || '').trim();

        this.selectedObject   = chosenObject;
        this.selectedField    = 'All fields';
        this.selectedOperator = 'Equal';
        this.searchValue      = '';
        this.resetPagination();
        this.showObjectDropdown = false;
        this.isLoading = true;

        try {
            const [fields, history] = await Promise.all([
                getTrackedFieldsForObject({ objectName: chosenObject }),
                getFieldHistory({
                    objectName: chosenObject,
                    fieldName:  null,
                    dateRange:  this.selectedDateRange
                })
            ]);

            this.fieldOptions = ['All fields', ...(fields || [])];
            this.applyHistory(history);

        } catch (e) {
            this.handleError(e);
        } finally {
            this.isLoading = false;
        }
    }

    async selectField(event) {
        event.stopPropagation();
        const chosenObject = this.selectedObject;                              // capture NOW
        const chosenField  = (event.currentTarget.dataset.value || '').trim(); // capture NOW

        this.selectedField    = chosenField;
        this.selectedOperator = 'Equal';
        this.searchValue      = '';
        this.resetPagination();
        this.showFieldDropdown = false;
        this.isLoading = true;

        try {
            const result = await getFieldHistory({
                objectName: chosenObject,
                fieldName:  chosenField === 'All fields' ? null : chosenField,
                dateRange:  this.selectedDateRange
            });

            // If Apex returned records for this exact field, use them.
            if (result && result.length > 0) {
                this.applyHistory(result);
                return;
            }
            if (chosenField !== 'All fields') {
                const objectHistory = await getFieldHistory({
                    objectName: chosenObject,
                    fieldName:  null,
                    dateRange:  this.selectedDateRange
                });

                if (objectHistory && objectHistory.length > 0) {
                    const norm = s => (s || '').toLowerCase().replace(/[^a-z0-9]/g, '');
                    const b = norm(chosenField);

                    const matches = (objectHistory || []).filter(h => {
                        const a = norm(h.fieldName);
                        if (!a || !b) return false;
                        if (a === b) return true;
                        if (a.endsWith(b) || b.endsWith(a)) return true;
                        if (a.includes(b) || b.includes(a)) return true;
                        return false;
                    });

                    if (matches.length > 0) {
                        this.applyHistory(matches);
                        return;
                    }
                    this.applyHistory([]);
                    const sampleFields = Array.from(new Set((objectHistory || []).map(h => h.fieldName))).slice(0,5);
                    const sampleMsg = sampleFields.length > 0 ? `Found history for fields: ${sampleFields.join(', ')}.` : '';
                    return;
                }
                this.applyHistory([]);
            } else {
                this.applyHistory([]);
            }

        } catch (e) {
            this.handleError(e);
        } finally {
            this.isLoading = false;
        }
    }
    selectOperator(event) {
        event.stopPropagation();
        this.selectedOperator = event.currentTarget.dataset.value;
        this.resetPagination();
        this.showOperatorDropdown = false;
    }

    async selectDate(event) {
        event.stopPropagation();
        this.selectedDateRange = event.currentTarget.dataset.value;
        this.resetPagination();
        this.showDateDropdown = false;
        this.isLoading = true;

        try {
            const [history, stats] = await Promise.all([
                getFieldHistory({
                    objectName: this.selectedObject,
                    fieldName:  this.selectedField === 'All fields' ? null : this.selectedField,
                    dateRange:  this.selectedDateRange
                }),
                getStatsSummary({ dateRange: this.selectedDateRange })
            ]);

            this.applyHistory(history);
            this.applyStats(stats);

        } catch (e) {
            this.handleError(e);
        } finally {
            this.isLoading = false;
        }
    }
    // ──────────────────────────────────────────────────────────────────────
    // Search — debounced, client-side filter only
    // ──────────────────────────────────────────────────────────────────────

    handleSearchInput(event) {
        const val = event.target.value;
        if (this._debounceTimer) clearTimeout(this._debounceTimer);
        this._debounceTimer = setTimeout(() => {
            this.searchValue = val;
            this.resetPagination();
        }, this.DEBOUNCE_DELAY);
    }

    clearSearch() {
        this.searchValue = '';
        this.resetPagination();
        const input = this.template.querySelector('.search-input');
        if (input) input.value = '';
    }

    // ──────────────────────────────────────────────────────────────────────
    // Pagination
    // ──────────────────────────────────────────────────────────────────────

    goToFirstPage()    { this.currentPage = 1; }
    goToLastPage()     { this.currentPage = this.totalPages; }

    goToPreviousPage() {
        this.currentPage = Math.max(this.normalizedCurrentPage - 1, 1);
    }

    goToNextPage() {
        this.currentPage = Math.min(this.normalizedCurrentPage + 1, this.totalPages);
    }

    handlePageSizeChange(event) {
        this.pageSize = Number(event.target.value);
        this.resetPagination();
    }

    // ──────────────────────────────────────────────────────────────────────
    // Button handlers
    // ──────────────────────────────────────────────────────────────────────

    openTrackingConfig() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Tracking Config', message: 'Tracking Config panel opened.', variant: 'info'
        }));
    }

    handleCloseModal() {
        this.showModal = false;
    }

    async exportCsv() {
        if (!this.showModal) {
            this.showModal = true;
        } else {
            try {
                const csvData = await exportFieldHistoryCsv({
                    objectName: this.selectedObject,
                    fieldName:  this.selectedField === 'All fields' ? null : this.selectedField,
                    dateRange:  this.selectedDateRange
                });

                if (csvData) {
                    const base64  = btoa(unescape(encodeURIComponent(csvData)));
                    const dataUri = 'data:text/csv;base64,' + base64;
                    const fileName = `FieldHistory_${this.selectedObject}_${new Date().toISOString().slice(0, 10)}.csv`;

                    const link = document.createElement('a');
                    link.href     = dataUri;
                    link.download = fileName;
                    link.style.display = 'none';
                    this.template.querySelector('.audit360-container').appendChild(link);
                    link.click();
                    this.template.querySelector('.audit360-container').removeChild(link);

                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success', message: 'CSV exported successfully!', variant: 'success'
                    }));
                }
            } catch (error) {
                this.handleError(error);
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────

    applyStats(result) {
        if (!result) return;
        this.caseChanges    = this.formatNumber(result.caseChanges);
        this.accountChanges = this.formatNumber(result.accountChanges);
        this.contactChanges = this.formatNumber(result.contactChanges);
        this.objectsTracked = this.formatNumber(result.objectsTracked);
    }

    applyHistory(result) {
        this.filteredHistory = (result || []).map((rec, idx) => ({
            id:              rec.id || String(idx),
            fieldName:       rec.fieldName,
            oldValueDisplay: rec.oldValue || '—',
            oldValueClass:   rec.oldValue ? 'old-value' : 'empty-dash',
            newValueDisplay: rec.newValue || '—',
            newValueClass:   rec.newValue ? 'new-value' : 'empty-dash',
            changedBy:       rec.changedBy,
            timestamp:       rec.timestamp
        }));
        this.resetPagination();
    }

    resetPagination() { this.currentPage = 1; }

    formatNumber(num) {
        if (!num && num !== 0) return '0';
        if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
        if (num >= 1000)    return Math.round(num / 1000) + 'K';
        return String(num);
    }

    handleError(error) {
        const msg = error?.body?.message || error?.message || 'An unexpected error occurred.';
        this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
    }
}