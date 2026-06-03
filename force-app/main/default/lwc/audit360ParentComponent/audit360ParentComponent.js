import { LightningElement, track } from 'lwc';
import Setup_Audit from '@salesforce/label/c.Setup_Audit';
import Email_Status from '@salesforce/label/c.Email_Status';
import Reports from '@salesforce/label/c.Reports';
import Job_Monitor from '@salesforce/label/c.Job_Monitor';
import Field_History from '@salesforce/label/c.Field_History';
import hasSetupAuditAccess from '@salesforce/customPermission/View_Setup_Audit_Tab';
import hasEmailStatusAccess from '@salesforce/customPermission/View_Email_Status_Tab';
import hasReportsAccess from '@salesforce/customPermission/View_Reports_Tab';
import hasJobMonitorAccess from '@salesforce/customPermission/View_Job_Monitor_Tab';
import hasFieldHistoryAccess from '@salesforce/customPermission/View_Field_History_Tab';
import hasLoginActivityMonitor from '@salesforce/customPermission/Login_Activity_Monitor';
import hasFieldAccessDashboardAccess from '@salesforce/customPermission/View_Field_Access_Dashboard_Tab';
import Audit360Logo from '@salesforce/resourceUrl/Audit360Logo';
//import Audit360Logo from "@salesforce/resourceUrl/Audit360Logo";
export default class Audit360App extends LightningElement {
   @track logoUrl = Audit360Logo;
    @track activeTab = 'setup';
    @track tabName;

    labels = {
        setupAudit: Setup_Audit,
        emailStatus: Email_Status,
        reports: Reports,
        jobMonitor: Job_Monitor,
        fieldHistory: Field_History
    };

    // Permission Variables
    hasSetupAuditAccess = hasSetupAuditAccess;
    hasEmailStatusAccess = hasEmailStatusAccess;
    hasReportsAccess = hasReportsAccess;
    hasJobMonitorAccess = hasJobMonitorAccess;
    hasFieldHistoryAccess = hasFieldHistoryAccess;
    hasFieldAccessDashboardAccess = hasFieldAccessDashboardAccess;
    hasLoginActivityMonitor = hasLoginActivityMonitor;

    handleTabChange(event) {
        this.activeTab = event.target.value;
        this.tabName = this.activeTab;
    }
}