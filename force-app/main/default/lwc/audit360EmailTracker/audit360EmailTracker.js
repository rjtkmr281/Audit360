import { LightningElement, track } from 'lwc';

import getDashboardData from '@salesforce/apex/Audit360_EmailController.getDashboardData';

// CUSTOM LABELS
import ET_All_Time from '@salesforce/label/c.ET_All_Time';
import ET_Custom_Range from '@salesforce/label/c.ET_Custom_Range';
import ET_This_Week from '@salesforce/label/c.ET_This_Week';
import ET_Last_Week from '@salesforce/label/c.ET_Last_Week';
import ET_This_Month from '@salesforce/label/c.ET_This_Month';
import ET_Last_Month from '@salesforce/label/c.ET_Last_Month';

import ET_Sent from '@salesforce/label/c.ET_Sent';
import ET_Read from '@salesforce/label/c.ET_Read';
import ET_Replied from '@salesforce/label/c.ET_Replied';
import ET_Draft from '@salesforce/label/c.ET_Draft';
import ET_Failed from '@salesforce/label/c.ET_Failed';

import ET_Emails from '@salesforce/label/c.ET_Emails';
import ET_Opened from '@salesforce/label/c.ET_Opened';
import ET_Responses from '@salesforce/label/c.ET_Responses';
import ET_Pending from '@salesforce/label/c.ET_Pending';
import ET_Bounced from '@salesforce/label/c.ET_Bounced';
import ET_NA from '@salesforce/label/c.ET_NA';
import ET_Refresh_Interval from '@salesforce/label/c.ET_Refresh_Interval';
import ET_Page_Size from '@salesforce/label/c.ET_Page_Size';

export default class Audit360EmailTracker extends LightningElement {

    labels = {
        ET_All_Time,
        ET_Custom_Range,
        ET_This_Week,
        ET_Last_Week,
        ET_This_Month,
        ET_Last_Month,
        ET_Sent,
        ET_Read,
        ET_Replied,
        ET_Draft,
        ET_Failed,
        ET_Emails,
        ET_Opened,
        ET_Responses,
        ET_Pending,
        ET_Bounced,
        ET_NA
    };

    @track data = {
        sentCount: 0,
        readCount: 0,
        repliedCount: 0,
        draftCount: 0,
        failedCount: 0,
        recentEmails: [],
        adminLogs: []
    };

    @track isLoading = false;
    @track kpiList = [];
    @track pagedEmails = [];
    @track showModal = false;

    allEmails = [];
    wiredResult;
    refreshInterval;

    selectedFilter = 'ALL';
    fromDate;
    toDate;
    isCustom = false;

    searchKey = '';
    searchText = '';

    currentPage = 1;
    pageSize = Number(ET_Page_Size);
    totalPages = 1;

    filterOptions = [
        {
            label: ET_All_Time,
            value: 'ALL'
        },
        {
            label: ET_Custom_Range,
            value: 'CUSTOM'
        },
        {
            label: ET_This_Week,
            value: 'THIS_WEEK'
        },
        {
            label: ET_Last_Week,
            value: 'LAST_WEEK'
        },
        {
            label: ET_This_Month,
            value: 'THIS_MONTH'
        },
        {
            label: ET_Last_Month,
            value: 'LAST_MONTH'
        }
    ];

    connectedCallback() {

        this.loadLiveData();

        this.refreshInterval = setInterval(() => {

            this.loadLiveData();

        }, Number(ET_Refresh_Interval));
    }

    disconnectedCallback() {

        if (this.refreshInterval) {

            clearInterval(this.refreshInterval);
        }
    }

    loadLiveData() {

        let dates = this.calculateDates();

        this.isLoading = true;

        getDashboardData({
            startDate: dates.startDate,
            endDate: dates.endDate
        })
            .then(data => {

                this.processData(data);

                this.isLoading = false;
            })
            .catch(error => {

                this.isLoading = false;

                console.error(
                    'Live refresh error:',
                    error
                );
            });
    }

    handleCloseModal() {

        this.showModal = false;
    }

    handleFilterChange(event) {

        this.showModal = event.detail.value == 'CUSTOM';

        if (!this.showModal) {

            this.selectedFilter = event.detail.value;

            this.isCustom = this.selectedFilter == 'CUSTOM';

            if (!this.isCustom) {

                this.loadLiveData();
            }
        }
    }

    handleFromDate(event) {

        this.fromDate = event.target.value;

        if (this.fromDate && this.toDate) {

            this.loadLiveData();
        }
    }

    handleToDate(event) {

        this.toDate = event.target.value;

        if (this.fromDate && this.toDate) {

            this.loadLiveData();
        }
    }

    handleSearchKeyChange(event) {

        this.searchText = event.target.value;
    }

    handleSearch() {

        if (this.refreshInterval) {

            clearInterval(this.refreshInterval);

            this.refreshInterval = null;
        }

        this.searchKey = this.searchText;

        this.filterEmails();
    }

    calculateDates() {

        if (this.selectedFilter == 'ALL') {

            return {
                startDate: null,
                endDate: null
            };
        }

        let today = new Date();

        let startDate;

        let endDate;

        switch (this.selectedFilter) {

            case 'THIS_WEEK':

                let firstDay =
                    today.getDate() - today.getDay();

                startDate = new Date(today);

                startDate.setDate(firstDay);

                endDate = new Date();

                break;

            case 'LAST_WEEK':

                startDate = new Date(today);

                startDate.setDate(
                    today.getDate() - today.getDay() - 7
                );

                endDate = new Date(today);

                endDate.setDate(
                    today.getDate() - today.getDay() - 1
                );

                break;

            case 'THIS_MONTH':

                startDate =
                    new Date(
                        today.getFullYear(),
                        today.getMonth(),
                        1
                    );

                endDate = new Date();

                break;

            case 'LAST_MONTH':

                startDate =
                    new Date(
                        today.getFullYear(),
                        today.getMonth() - 1,
                        1
                    );

                endDate =
                    new Date(
                        today.getFullYear(),
                        today.getMonth(),
                        0
                    );

                break;

            case 'CUSTOM':

                return {
                    startDate: this.fromDate,
                    endDate: this.toDate
                };
        }

        return {

            startDate:
                startDate
                    .toISOString()
                    .split('T')[0],

            endDate:
                endDate
                    .toISOString()
                    .split('T')[0]
        };
    }

    processData(data) {

        const total =
            (data.sentCount || 0) +
            (data.readCount || 0) +
            (data.repliedCount || 0) +
            (data.draftCount || 0) +
            (data.failedCount || 0);

        const percent = (val) =>
            total
                ? (
                    (val / total) * 100
                ).toFixed(1)
                : 0;

        this.allEmails =
            (data.recentEmails || [])
                .map(email => {

                    let statusLabel =
                        this.getStatusLabel(
                            email.Status,
                            email.IsBounced
                        );

                    return {
                        ...email,

                        statusLabel,

                        statusClass:
                            'status ' +
                            statusLabel.toLowerCase(),

                        dotClass:
                            'dot ' +
                            statusLabel.toLowerCase(),

                        time:
                            this.formatTime(
                                email.CreatedDate
                            ),

                        fromAddress:
                            email.FromAddress || ET_NA,

                        toAddress:
                            email.ToAddress || ET_NA
                    };
                });

        this.data = {
            ...data,

            sentPercent:
                percent(data.sentCount),

            readPercent:
                percent(data.readCount),

            repliedPercent:
                percent(data.repliedCount),

            draftPercent:
                percent(data.draftCount),

            failedPercent:
                percent(data.failedCount),

            recentEmails:
                this.allEmails
        };

        this.currentPage = 1;

        this.updatePagination(this.allEmails);

        this.kpiList = [
            {
                id: 1,
                number: data.sentCount,
                label: ET_Sent,
                subject: ET_Emails,
                color: 'kpiGreen'
            },
            {
                id: 2,
                number: data.readCount,
                label: ET_Read,
                subject: ET_Opened,
                color: 'kpiBlue'
            },
            {
                id: 3,
                number: data.repliedCount,
                label: ET_Replied,
                subject: ET_Responses,
                color: 'kpiOrange'
            },
            {
                id: 4,
                number: data.draftCount,
                label: ET_Draft,
                subject: ET_Pending,
                color: 'kpiSlety'
            },
            {
                id: 5,
                number: data.failedCount,
                label: ET_Failed,
                subject: ET_Bounced,
                color: 'kpiRed'
            }
        ];
    }

    filterEmails() {

        let filteredEmails =
            [...this.allEmails];

        if (this.searchKey) {

            const keyword =
                this.searchKey.toLowerCase();

            filteredEmails =
                filteredEmails.filter(email => {

                    const subject =
                        (email.Subject || '')
                            .toLowerCase();

                    const fromAddress =
                        (email.fromAddress || '')
                            .toLowerCase();

                    const toAddress =
                        (email.toAddress || '')
                            .toLowerCase();

                    return (
                        subject.includes(keyword)
                        ||
                        fromAddress.includes(keyword)
                        ||
                        toAddress.includes(keyword)
                    );
                });
        }

        this.currentPage = 1;

        this.data = {
            ...this.data,
            recentEmails: filteredEmails
        };

        this.updatePagination(filteredEmails);
    }

    get sentStyle() {
        return `width:${this.data.sentPercent}%`;
    }

    get readStyle() {
        return `width:${this.data.readPercent}%`;
    }

    get repliedStyle() {
        return `width:${this.data.repliedPercent}%`;
    }

    get draftStyle() {
        return `width:${this.data.draftPercent}%`;
    }

    get failedStyle() {
        return `width:${this.data.failedPercent}%`;
    }

    get selectedFilterLabel() {

        switch (this.selectedFilter) {

            case 'THIS_WEEK':
                return ET_This_Week;

            case 'LAST_WEEK':
                return ET_Last_Week;

            case 'THIS_MONTH':
                return ET_This_Month;

            case 'LAST_MONTH':
                return ET_Last_Month;

            case 'CUSTOM':
                return ET_Custom_Range;

            default:
                return ET_All_Time;
        }
    }

    getStatusLabel(status, isBounced) {

        if (isBounced === true) {

            return ET_Failed;
        }

        switch (String(status)) {

            case '3':
                return ET_Sent;

            case '2':
                return ET_Replied;

            case '1':
                return ET_Read;

            case '0':
                return ET_Draft;

            default:
                return ET_Sent;
        }
    }

    formatTime(dateStr) {

        const d = new Date(dateStr);

        const datePart =
            d.toLocaleDateString(
                'en-IN',
                {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric'
                }
            );

        const timePart =
            d.toLocaleTimeString(
                'en-IN',
                {
                    hour: '2-digit',
                    minute: '2-digit',
                    hour12: true
                }
            );

        return `${datePart} • ${timePart}`;
    }

    renderedCallback() {

        if (this.loaded) {

            return;
        }

        const dateInputs =
            this.template.querySelectorAll(
                'lightning-input[data-ui]'
            );

        if (dateInputs.length > 0) {

            dateInputs.forEach(input => {

                const style =
                    document.createElement('style');

                style.innerText = `
                    .slds-form-element__help {
                        display: none !important;
                    }

                    .slds-form-element {
                        padding-bottom: 0 !important;
                        margin-bottom: 0 !important;
                    }
                `;

                try {

                    input.appendChild(style);

                } catch (e) {

                    console.error(e);
                }
            });

            this.loaded = true;
        }
    }

    handleReset() {

        this.searchKey = '';

        this.searchText = '';

        const searchBox =
            this.template.querySelector(
                '.search-box'
            );

        if (searchBox) {

            searchBox.value = '';
        }

        this.data = {
            ...this.data,
            recentEmails: [...this.allEmails]
        };

        if (this.refreshInterval) {

            clearInterval(this.refreshInterval);
        }

        this.refreshInterval = setInterval(() => {

            this.loadLiveData();

        }, Number(ET_Refresh_Interval));

        this.loadLiveData();
    }

    updatePagination(emailList) {

        this.totalPages =
            Math.ceil(
                emailList.length / this.pageSize
            );

        if (this.totalPages === 0) {

            this.totalPages = 1;
        }

        const start =
            (this.currentPage - 1) *
            this.pageSize;

        const end =
            start + this.pageSize;

        this.pagedEmails =
            emailList.slice(start, end);
    }

    handleNext() {

        if (!this.showModal) {

            this.showModal = true;

        } else {

            if (this.currentPage < this.totalPages) {

                this.currentPage++;

                this.updatePagination(
                    this.data.recentEmails
                );
            }
        }
    }

    handlePrevious() {

        if (this.currentPage > 1) {

            this.currentPage--;

            this.updatePagination(
                this.data.recentEmails
            );
        }
    }

    get isPreviousDisabled() {

        return this.currentPage === 1;
    }

    get isNextDisabled() {

        return this.currentPage === this.totalPages;
    }
}