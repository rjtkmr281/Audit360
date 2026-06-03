/**
 * Controller class used for managing and monitoring Apex jobs.
 *
 * Features:
 * - Fetch Batch, Queueable, and Scheduled Apex jobs
 * - Filter jobs by type or failed status
 * - Abort scheduled jobs
 * - Reschedule Apex schedulable jobs
 *
 * Notes:
 * - Wrapper class is used to send structured job data to LWC/Aura.
 * - Supports job monitoring dashboards.
 * - Uses AsyncApexJob and CronTrigger for runtime details.
 */
public Without Sharing class Audit360_JobController {

    /**
     * Wrapper class used to expose Apex job details
     * to Lightning components.
     */
    public class JobWrapper {

        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String CreatedByName;
        @AuraEnabled public String LastModifiedByName;
        @AuraEnabled public Datetime CreatedDate;

        // Job type: BatchApex, Queueable, ScheduledApex
        @AuraEnabled public String Type;

        // Current execution status
        @AuraEnabled public String RunStatus;

        // Scheduled job details
        @AuraEnabled public Datetime LastRunTime;
        @AuraEnabled public Datetime NextFireTime;
        @AuraEnabled public String CronTriggerId;
    }

    /**
     * Fetches Apex jobs based on selected filter type.
     *
     * Supported filters:
     * - ALL
     * - FAILED
     * - BatchApex
     * - Queueable
     * - ScheduledApex
     *
     * @param jobType Selected job filter
     * @return List<JobWrapper>
     */
    @AuraEnabled(cacheable=true)
    public static List<JobWrapper> getJobs(String jobType) {

        List<JobWrapper> result = new List<JobWrapper>();

        // Fetch all Apex classes
        List<ApexClass> classes = [
            SELECT Id,
                   Name,
                   Body,
                   CreatedBy.Name,
                   LastModifiedBy.Name,
                   CreatedDate
            FROM ApexClass
            LIMIT 50000
        ];

        // Fetch async execution job details
        List<AsyncApexJob> jobs = [
            SELECT Id,
                   ApexClass.Name,
                   JobType,
                   Status
            FROM AsyncApexJob
            LIMIT 50000
        ];

        // Fetch scheduled job details
        List<CronTrigger> cronList = [
            SELECT Id,
                   CronJobDetail.Name,
                   PreviousFireTime,
                   NextFireTime,
                   State
            FROM CronTrigger
            LIMIT 50000
        ];

        // Map Apex class name to AsyncApexJob
        Map<String, AsyncApexJob> jobMap = new Map<String, AsyncApexJob>();

        for (AsyncApexJob job : jobs) {
            jobMap.put(job.ApexClass.Name, job);
        }

        // Map scheduled class name to CronTrigger
        Map<String, CronTrigger> cronMap = new Map<String, CronTrigger>();

        for (CronTrigger ct : cronList) {
            cronMap.put(ct.CronJobDetail.Name, ct);
        }

        // Process all Apex classes
        for (ApexClass cls : classes) {

            String type = '';

            // Identify job type based on implemented interface
            if (cls.Body != null && cls.Body.contains('Database.Batchable')) {

                type = 'BatchApex';

            } else if (cls.Body != null && cls.Body.contains('Schedulable')) {

                type = 'ScheduledApex';

            } else if (cls.Body != null && cls.Body.contains('Queueable')) {

                type = 'Queueable';
            }

            // Apply selected filter
            if (jobType != 'ALL' &&
                jobType != 'FAILED' &&
                type != jobType) {

                continue;
            }

            JobWrapper wrap = new JobWrapper();

            wrap.Id = cls.Id;
            wrap.Name = cls.Name;
            wrap.CreatedByName = cls.CreatedBy.Name;
            wrap.LastModifiedByName = cls.LastModifiedBy.Name;
            wrap.CreatedDate = cls.CreatedDate;
            wrap.Type = type;

            // Populate scheduled job runtime details
            if (type == 'ScheduledApex' &&
                cronMap.containsKey(cls.Name)) {

                CronTrigger ct = cronMap.get(cls.Name);

                wrap.CreatedByName = cls.CreatedBy.Name;
                wrap.LastModifiedByName = cls.LastModifiedBy.Name;
                wrap.CreatedDate = cls.CreatedDate;

                wrap.LastRunTime = ct.PreviousFireTime;
                wrap.NextFireTime = ct.NextFireTime;
                wrap.CronTriggerId = ct.Id;
            }

            // Populate async execution status
            if (jobMap.containsKey(cls.Name)) {

                AsyncApexJob job = jobMap.get(cls.Name);

                // Return only failed jobs when FAILED filter is selected
                if (jobType == 'FAILED') {

                    if (job.Status == 'Failed') {

                        wrap.RunStatus = 'Failed';
                        result.add(wrap);
                    }

                    continue;
                }

                wrap.RunStatus = job.Status;

            } else {

                // Ignore jobs with no execution record when filtering FAILED
                if (jobType == 'FAILED') {
                    continue;
                }

                wrap.RunStatus = 'Never';
            }

            result.add(wrap);
        }

        return result;
    }

    /**
     * Aborts a scheduled Apex job using CronTrigger Id.
     *
     * @param cronId CronTrigger Id
     */
    @AuraEnabled
    public static void abortJob(String cronId) {

        System.abortJob(cronId);
    }

    /**
     * Reschedules a schedulable Apex job using a new schedule time.
     *
     * @param className Apex schedulable class name
     * @param scheduleTime New execution datetime
     */
    @AuraEnabled
    public static void rescheduleJob(
        String className,
        Datetime scheduleTime
    ) {

        // Build cron expression dynamically
        String cronExp =
            scheduleTime.second() + ' ' +
            scheduleTime.minute() + ' ' +
            scheduleTime.hour() + ' ' +
            scheduleTime.day() + ' ' +
            scheduleTime.month() + ' ? ' +
            scheduleTime.year();

        // Schedule the Apex class
        System.schedule(
            className + ' Rescheduled',
            cronExp,
            (Schedulable) Type.forName(className).newInstance()
        );
    }
}