import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getReportFolders from '@salesforce/apex/Audit360_ReportController.getReportFolders';
import getReportsByFolder from '@salesforce/apex/Audit360_ReportController.getReportsByFolder';
import getAllReports from '@salesforce/apex/Audit360_ReportController.getAllReports';
import getDashboardStats from '@salesforce/apex/Audit360_ReportController.getDashboardStats';
import getDownloadTrackingLogs from '@salesforce/apex/Audit360_ReportController.getDownloadTrackingLogs';

const MAX_VISIBLE_TABS = 5;
const PAGE_SIZE_REPORTS = 10;
const PAGE_SIZE_DOWNLOADS = 5;    // 5 download logs per page

export default class Audit360_ReportTracker extends NavigationMixin(LightningElement) {

    @track allFolders = [];
    @track selectedFolderId = 'ALL';
    @track downloadLogs = [];
    @track isLoadingReports = false;
    @track isLoadingDownloads = false;
    @track allReports = [];
    @track isLoading = false;

    // Private backing field for the currently filtered report list
    @track _allFilteredReports = [];

    // Stats
    @track todayRunCount = 0;
    @track last7DaysCount = 0;
    @track topFolder = '';
    @track formatCount = 0;
    @track formatsList = '';

    // ── Pagination state ──────────────────────────────
    @track currentPageReports = 1;
    @track currentPageDownloads = 1;

    // ─────────────────────────────────────────────
    // LIFECYCLE
    // ─────────────────────────────────────────────

    connectedCallback() {
        this.loadFolders();
        this.loadStats();
        this.loadAllReports();
        this.loadDownloadLogs();
    }

    // ─────────────────────────────────────────────
    // DATA LOADING
    // ─────────────────────────────────────────────

    loadFolders() {
        getReportFolders()
            .then(result => {
                const allTab = { id: 'ALL', name: 'All Folders' };
                const folderTabs = (result || []).map(f => ({ id: f.Id, name: f.Name }));
                this.allFolders = [allTab, ...folderTabs];
            })
            .catch(error => {
                console.error('Error loading folders:', error);
            });
    }

    loadStats() {
        getDashboardStats()
            .then(result => {
                if (result) {
                    this.todayRunCount = result.todayRunCount || 0;
                    this.last7DaysCount = result.last7DaysCount || 0;
                    this.topFolder = result.topFolder || 'N/A';
                    this.formatCount = result.formatCount || 0;
                    this.formatsList = result.formatsList || '';
                }
            })
            .catch(error => {
                console.error('Error loading stats:', error);
            });
    }

    loadAllReports() {
        this.isLoading = true;
        this.isLoadingReports = true;
        getAllReports()
            .then(result => {
                this.allReports = this.formatReports(result || []);
                this._allFilteredReports = [...this.allReports];
                this.currentPageReports = 1;           // reset to page 1
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading reports:', error);
            })
            .finally(() => {
                this.isLoadingReports = false;
            });
    }

    loadDownloadLogs() {
        this.isLoadingDownloads = true;
        getDownloadTrackingLogs()
            .then(result => {
                this.downloadLogs = this.formatDownloadLogs(result || []);
                this.currentPageDownloads = 1;         // reset to page 1
            })
            .catch(error => {
                console.error('Error loading download logs:', error);
            })
            .finally(() => {
                this.isLoadingDownloads = false;
            });
    }

    loadReportsByFolder(folderId) {
        this.isLoadingReports = true;
        getReportsByFolder({ folderId: folderId })
            .then(result => {
                this._allFilteredReports = this.formatReports(result || []);
                this.currentPageReports = 1;           // reset to page 1 on folder change
            })
            .catch(error => {
                console.error('Error loading reports by folder:', error);
            })
            .finally(() => {
                this.isLoadingReports = false;
            });
    }

    // ─────────────────────────────────────────────
    // FORMATTERS
    // ─────────────────────────────────────────────

    formatReports(reports) {
        return reports.map(r => {
            const lastRun = r.LastRunDate ? new Date(r.LastRunDate) : null;
            const statusCalculation = r.LastRunDate ? new Date(r.LastRunDate) : null;
            return {
                id: r.Id,
                name: r.Name,
                folderName: r.FolderName || '',
                folderId: r.OwnerId || '',
                format: r.Format || 'Summary',
                runBy: r.Runby || '',
                formatBadgeClass: this.getFormatBadgeClass(r.Format),
                lastRunDisplay: lastRun ? this.formatLastRun(lastRun) : 'Never',
                staus: statusCalculation ? this.formatStatus(statusCalculation) : 'Never Run',
                url: `/lightning/r/Report/${r.Id}/view`
            };
        });
    }

    formatDownloadLogs(logs) {
        return logs.map(log => {
            const eventTime = log.EventDate ? new Date(log.EventDate) : null;
            return {
                id: log.Id,
                reportName: log.reportName || '',
                reportUrl: log.reportId ? `/lightning/r/Report/${log.reportId}/view` : '#',
                downloadedBy: log.downloadedBy || '',
                format: log.Format || 'Summary',
                formatBadgeClass: this.getFormatBadgeClass(log.Format),
                timeDisplay: eventTime ? this.formatTime(eventTime) : '',
                folderName: log.folderName || ''
            };
        });
    }

    getFormatBadgeClass(format) {
        const base = 'format-badge';
        if (!format) return base + ' badge-summary';
        const f = format.toLowerCase();
        if (f === 'matrix') return base + ' badge-matrix';
        if (f === 'tabular') return base + ' badge-tabular';
        if (f === 'csv') return base + ' badge-csv';
        if (f === 'excel') return base + ' badge-excel';
        return base + ' badge-summary';
    }

    formatLastRun(date) {
        const timeStr = date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false });
        const dateStr = date.toLocaleDateString('en-GB');
        return `${dateStr} ${timeStr}`;
    }

    formatStatus(date) {
        if (!date) return 'Never Run';
        const today = new Date();
        const todayOnly = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        const runDateOnly = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        const diffDays = Math.floor((todayOnly - runDateOnly) / (1000 * 60 * 60 * 24));
        if (diffDays === 0) return 'Run Today';
        if (diffDays === 1) return '1 Day Ago';
        return `${diffDays} Days Ago`;
    }

    formatTime(date) {
        const timeStr = date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false });
        const dateStr = date.toLocaleDateString('en-GB');
        return `${dateStr} ${timeStr}`;
    }

    // ─────────────────────────────────────────────
    // EVENT HANDLERS — Folder Tabs
    // ─────────────────────────────────────────────

    handleFolderTabClick(event) {
        const folderId = event.currentTarget.dataset.id;
        this.selectedFolderId = folderId;
        if (folderId === 'ALL') {
            this._allFilteredReports = [...this.allReports];
            this.currentPageReports = 1;
        } else {
            this.loadReportsByFolder(folderId);
        }
    }

    handlePicklistChange(event) {
        const folderId = event.target.value;
        if (!folderId) return;
        this.selectedFolderId = folderId;
        this.loadReportsByFolder(folderId);
    }

    handleReportClick(event) {
        event.preventDefault();
        const reportId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: reportId,
                objectApiName: 'Report',
                actionName: 'view'
            }
        });
    }

    // ─────────────────────────────────────────────
    // PAGINATION — Reports (10 per page)
    // ─────────────────────────────────────────────

    get pagedReports() {
        const start = (this.currentPageReports - 1) * PAGE_SIZE_REPORTS;
        return (this._allFilteredReports || []).slice(start, start + PAGE_SIZE_REPORTS);
    }

    get totalPagesReports() {
        return Math.ceil((this._allFilteredReports || []).length / PAGE_SIZE_REPORTS) || 1;
    }

    get isFirstPageReports() {
        return this.currentPageReports === 1;
    }

    get isLastPageReports() {
        return this.currentPageReports >= this.totalPagesReports;
    }

    get pageInfoReports() {
        const total = (this._allFilteredReports || []).length;
        const start = (this.currentPageReports - 1) * PAGE_SIZE_REPORTS + 1;
        const end = Math.min(this.currentPageReports * PAGE_SIZE_REPORTS, total);
        return `Page ${this.currentPageReports} of ${this.totalPagesReports} (${start}–${end} of ${total})`;
    }

    get statusMsgReports() {
        const total = (this._allFilteredReports || []).length;
        return `Showing ${this.pagedReports.length} of ${total} reports · Click any row to expand`;
    }

    handlePrevReports() {
        if (!this.isFirstPageReports) this.currentPageReports--;
    }

    handleNextReports() {
        if (!this.isLastPageReports) this.currentPageReports++;
    }

    // ─────────────────────────────────────────────
    // PAGINATION — Downloads (5 per page)
    // ─────────────────────────────────────────────

    get pagedDownloads() {
        const start = (this.currentPageDownloads - 1) * PAGE_SIZE_DOWNLOADS;
        return (this.downloadLogs || []).slice(start, start + PAGE_SIZE_DOWNLOADS);
    }

    get totalPagesDownloads() {
        return Math.ceil((this.downloadLogs || []).length / PAGE_SIZE_DOWNLOADS) || 1;
    }

    get isFirstPageDownloads() {
        return this.currentPageDownloads === 1;
    }

    get isLastPageDownloads() {
        return this.currentPageDownloads >= this.totalPagesDownloads;
    }

    get pageInfoDownloads() {
        const total = (this.downloadLogs || []).length;
        const start = (this.currentPageDownloads - 1) * PAGE_SIZE_DOWNLOADS + 1;
        const end = Math.min(this.currentPageDownloads * PAGE_SIZE_DOWNLOADS, total);
        return `Page ${this.currentPageDownloads} of ${this.totalPagesDownloads} (${start}–${end} of ${total})`;
    }

    get statusMsgDownloads() {
        const total = (this.downloadLogs || []).length;
        return `Showing ${this.pagedDownloads.length} of ${total} download logs`;
    }

    handlePrevDownloads() {
        if (!this.isFirstPageDownloads) this.currentPageDownloads--;
    }

    handleNextDownloads() {
        if (!this.showModal) {
            this.showModal = true;
        } else {
            this.showModal = false;
            if (!this.isLastPageDownloads) this.currentPageDownloads++;
        }
    }
    @track showModal = false;
    handleCloseModal() {
        this.showModal = false;
    }
    // ─────────────────────────────────────────────
    // COMPUTED / GETTERS — Folders & KPIs
    // ─────────────────────────────────────────────

    get visibleFolderTabs() {
        return this.allFolders.slice(0, MAX_VISIBLE_TABS).map(f => ({
            ...f,
            cssClass: this.selectedFolderId === f.id
                ? 'folder-tab folder-tab-active'
                : 'folder-tab'
        }));
    }

    get showFolderPicklist() {
        return this.allFolders.length > MAX_VISIBLE_TABS;
    }

    get extraFolders() {
        return this.allFolders.slice(MAX_VISIBLE_TABS);
    }

    get hasReports() {
        return this._allFilteredReports && this._allFilteredReports.length > 0;
    }

    get hasDownloadLogs() {
        return this.downloadLogs && this.downloadLogs.length > 0;
    }

    get kpiList() {
        return [
            {
                id: 'todayRunCount',
                number: this.todayRunCount,
                label: 'Run Today',
                subject: 'Reports',
                color: 'kpiGreen'
            },
            {
                id: 'last7DaysCount',
                number: this.last7DaysCount,
                label: 'Last 7 Days',
                subject: 'Total Runs',
                color: 'kpiGreen'
            },
            {
                id: 'topFolder',
                number: this.topFolder || 'N/A',
                label: 'Top Folder',
                subject: 'Most Active',
                color: 'kpiBlue'
            },
            {
                id: 'formatCount',
                number: `${this.formatCount} Types`,
                label: 'Formats',
                subject: this.formatsList || 'No Formats',
                color: 'kpiBlue'
            }
        ];
    }
}