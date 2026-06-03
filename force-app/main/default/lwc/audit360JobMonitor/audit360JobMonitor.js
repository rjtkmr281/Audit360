import { LightningElement, track, wire } from 'lwc';
import getJobs from '@salesforce/apex/Audit360_JobController.getJobs';
import abortJob from '@salesforce/apex/Audit360_JobController.abortJob';
import rescheduleJob from '@salesforce/apex/Audit360_JobController.rescheduleJob';
import getKPIData from '@salesforce/apex/Audit360_DashboardController.getKPIData';
const PAGE_SIZE = 20;
export default class Audit360JobMonitor extends LightningElement {
    @track kpiList = [];
    @track jobList = [];
    @track allData = [];
    @track isLoading = false;
    searchKey = '';
    fromDate;
    toDate;
    selectedButton = 'All Async Jobs';
    isModalOpen = false;
    selectedClassName = '';
    selectedDateTime;
    currentPage = 0;
    batchColumns = [
        {
            label: 'Class Name',
            fieldName: 'Name'
        },
        {
            label: 'Created By',
            fieldName: 'CreatedByName'
        },
        {
            label: 'Modified By',
            fieldName: 'LastModifiedByName'
        },
        {
            label: 'Created Date',
            fieldName: 'CreatedDate',
            type: 'date'
        },
        {
            label: 'Running Status',
            fieldName: 'RunStatus'
        }
    ];

    commonColumns = [
        {
            label: 'Class Name',
            fieldName: 'Name'
        },
        {
            label: 'Type',
            fieldName: 'Type'
        },
        {
            label: 'Created By',
            fieldName: 'CreatedByName'
        },
        {
            label: 'Modified By',
            fieldName: 'LastModifiedByName'
        },
        {
            label: 'Created Date',
            fieldName: 'CreatedDate',
            type: 'date'
        },
        {
            label: 'Running Status',
            fieldName: 'RunStatus'
        }
    ];

    scheduledColumns = [
        {
            label: 'Class Name',
            fieldName: 'Name'
        },
        {
            label: 'Created By',
            fieldName: 'CreatedByName'
        },
        {
            label: 'Modified By',
            fieldName: 'LastModifiedByName'
        },
        {
            label: 'Created Date',
            fieldName: 'CreatedDate',
            type: 'date'
        },
        {
            label: 'Last Run',
            fieldName: 'LastRunTime',
            type: 'date'
        },
        {
            label: 'Next Run',
            fieldName: 'NextFireTime',
            type: 'date'
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    {
                        label: 'Abort',
                        name: 'abort'
                    },
                    {
                        label: 'Reschedule',
                        name: 'reschedule'
                    }
                ]
            }
        }
    ];

   
    @track columns = this.batchColumns;

    connectedCallback() {
        this.columns = this.commonColumns;
        this.loadJobs('ALL');
    }

   
    @wire(getKPIData)
    wiredData({ data, error }) {

        if (data) {

            this.kpiList = [
                {
                    id: 1,
                    number: data.completed,
                    label: 'Completed',
                    subject: 'Last 7 Days',
                    color: 'kpiGreen'
                },
                {
                    id: 2,
                    number: data.failed,
                    label: 'Failed',
                    subject: 'INACTIVE_OWNER',
                    color: 'kpiRed '
                },
                {
                    id: 3,
                    number: data.aborted,
                    label: 'Aborted',
                    subject: 'Scheduled',
                    color: 'kpiOrange'
                },
                {
                    id: 4,
                    number: data.queued,
                    label: 'Queued Now',
                    subject: 'Scheduled Apex',
                    color: 'kpiSlety'
                },
                {
                    id: 5,
                    number: data.successRate + '%',
                    label: 'Async Limit',
                    subject: 'Usage',
                    color: 'kpiBlue'
                }
            ];

        } else if (error) {
            console.error('KPI Error => ', error);
        }
    }

    loadJobs(type) {
        this.isLoading = true;
        getJobs({ jobType: type })
            .then(result => {
                this.allData = result || [];
                this.jobList = result || [];
                this.currentPage = 0;
                this.isLoading = false;

            })
            .catch(error => {
                console.error('Error => ', error);
                this.isLoading = false;

            });
    }

    handleclick(event) {
        const label = event.currentTarget.dataset.name;
        this.selectedButton = label;
        let type;
        if (label === 'All Async Jobs') {
            type = 'ALL';
            this.columns = this.commonColumns;
        }
        else if (label === 'Batch Apex') {
            type = 'BatchApex';
            this.columns = this.batchColumns;
        }
        else if (label === 'Scheduled') {
            type = 'ScheduledApex';
            this.columns = this.scheduledColumns;
        }
        else if (label === 'Queueable') {
            type = 'Queueable';
            this.columns = this.commonColumns;
        }
        else if (label === 'Failed Only') {
            type = 'FAILED';
            this.columns = this.commonColumns;

        }
        this.loadJobs(type);
    }
    handleSearch(event) {

        this.searchKey = event.target.value;

    }
    handleFromDate(event) {
        this.fromDate = event.target.value;
    }
    handleToDate(event) {
        this.toDate = event.target.value;
    }
    applyFilter() {

        let filtered = [...this.allData];

        // SEARCH FILTER

        if (this.searchKey) {

            filtered = filtered.filter(item =>

                item.Name &&
                item.Name.toLowerCase().includes(
                    this.searchKey.toLowerCase()
                )

            );
        }

        // FROM DATE FILTER

        if (this.fromDate) {

            const from = new Date(this.fromDate);
            from.setHours(0, 0, 0, 0);

            filtered = filtered.filter(item => {

                const createdDate = new Date(item.CreatedDate);

                return createdDate >= from;
            });
        }

        // TO DATE FILTER

        if (this.toDate) {

            const to = new Date(this.toDate);

            // IMPORTANT
            // Full day include karne ke liye
            to.setHours(23, 59, 59, 999);

            filtered = filtered.filter(item => {

                const createdDate = new Date(item.CreatedDate);

                return createdDate <= to;
            });
        }

        this.jobList = filtered;
        this.currentPage = 0;
    }
    handleReset() {

        this.searchKey = '';
        this.fromDate = null;
        this.toDate = null;

        this.template.querySelectorAll('lightning-input')
            .forEach(input => {

                input.value = null;

            });

        this.jobList = [...this.allData];
        this.currentPage = 0;
    }

    handlePrev() {
        if (!this.isFirstPage) {
            this.currentPage -= 1;
        }
    }

       @track showModal = false;
    handleCloseModal() {
        this.showModal = false;
    }


    handleNext() {
         if (!this.showModal) {
            this.showModal = true;
        } else {
        if (!this.isLastPage) {
            this.currentPage += 1;
        }
        }
    }
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'abort') {
            abortJob({
                cronId: row.CronTriggerId
            })
                .then(() => {

                    this.loadJobs('ScheduledApex');

                })
                .catch(error => {
                    console.error(error);
                });
        }

        // RESCHEDULE JOB

        if (actionName === 'reschedule') {

            this.selectedClassName = row.Name;

            this.isModalOpen = true;
        }
    }

    closeModal() {

        this.isModalOpen = false;

    }

    handleDateTimeChange(event) {

        this.selectedDateTime = event.target.value;

    }

    scheduleJob() {

        if (!this.selectedDateTime) {

            alert('Please select date & time');

            return;
        }

        rescheduleJob({

            className: this.selectedClassName,
            scheduleTime: this.selectedDateTime

        })

            .then(() => {

                alert('Job Scheduled Successfully');

                this.isModalOpen = false;

                this.loadJobs('ScheduledApex');

            })

            .catch(error => {

                this.isModalOpen = false;

                console.error(error);

            });
    }

    get allClass() {
        return this.selectedButton === 'All Async Jobs'
            ? 'folder-tab folder-tab-active'
            : 'folder-tab'
    }

    get batchClass() {

        return this.selectedButton === 'Batch Apex'
            ? 'folder-tab folder-tab-active'
            : 'folder-tab'
    }

    get scheduledClass() {

        return this.selectedButton === 'Scheduled'
            ? 'folder-tab folder-tab-active'
            : 'folder-tab'
    }

    get queueableClass() {

        return this.selectedButton === 'Queueable'
            ? 'folder-tab folder-tab-active'
            : 'folder-tab'
    }

    get failedClass() {

        return this.selectedButton === 'Failed Only'
            ? 'folder-tab folder-tab-active'
            : 'folder-tab'
    }

    get pagedJobList() {
        const start = this.currentPage * PAGE_SIZE;
        return this.jobList.slice(start, start + PAGE_SIZE);
    }

    get totalPages() {
        return Math.max(Math.ceil(this.jobList.length / PAGE_SIZE), 1);
    }

    get isFirstPage() {
        return this.currentPage === 0;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages - 1;
    }

    get pageInfo() {
        const total = this.jobList.length;
        if (total === 0) {
            return 'Showing 0 of 0 jobs';
        }
        const start = this.currentPage * PAGE_SIZE + 1;
        const end = Math.min((this.currentPage + 1) * PAGE_SIZE, total);
        return `Showing ${start}-${end} of ${total} jobs`;
    }
}