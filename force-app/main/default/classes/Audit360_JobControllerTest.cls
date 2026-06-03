@IsTest
public class Audit360_JobControllerTest {
	
    /*
     * --------------------------------------------
     * TEST SCHEDULABLE CLASS
     * --------------------------------------------
     */
    public class TestScheduler implements Schedulable {
        public void execute(SchedulableContext sc) {
            System.debug('Test Scheduler Executed');
        }
    }

    /*
     * --------------------------------------------
     * TEST QUEUEABLE CLASS
     * --------------------------------------------
     */
    public class TestQueueable implements Queueable {
        public void execute(QueueableContext qc) {
            System.debug('Queueable Executed');
        }
    }

    /*
     * --------------------------------------------
     * TEST BATCH CLASS
     * --------------------------------------------
     */
  /*  public class TestBatch implements Database.Batchable<SObject> {

        public Database.QueryLocator start(Database.BatchableContext bc) {
            return Database.getQueryLocator([
                SELECT Id FROM Account
            ]);
        }

        public void execute(Database.BatchableContext bc, List<SObject> scope) {
            System.debug('Batch Executed');
        }

        public void finish(Database.BatchableContext bc) {
            System.debug('Batch Finished');
        }
    }*/

    /*
     * --------------------------------------------
     * TEST DATA
     * --------------------------------------------
     */
    @testSetup
    static void setupData() {

        List<Account> accList = new List<Account>();

        for(Integer i = 0; i < 1000; i++) {
            accList.add(new Account(
                Name = 'Test Account ' + i,Phone = '587090'
            ));
        }

        insert accList;
    }

    /*
     * --------------------------------------------
     * TEST getJobs()
     * --------------------------------------------
     */
    @isTest
    static void testGetJobs() {

        // Schedule Job
        String cronExp = '0 0 12 * * ?';

        Test.startTest();

        System.schedule(
            'Test Scheduler Job',
            cronExp,
            new TestScheduler()
        );

        // Queueable
        System.enqueueJob(new TestQueueable());

        // Batch
       // Database.executeBatch(new TestBatch(), 1);

        Test.stopTest();

        // ALL
        List<Audit360_JobController.JobWrapper> allJobs =
            Audit360_JobController.getJobs('ALL');

        System.assertNotEquals(
            null,
            allJobs
        );

        // FAILED
        List<Audit360_JobController.JobWrapper> failedJobs =
            Audit360_JobController.getJobs('FAILED');

        System.assertNotEquals(
            null,
            failedJobs
        );

        // BatchApex
        List<Audit360_JobController.JobWrapper> batchJobs =
            Audit360_JobController.getJobs('BatchApex');

        System.assertNotEquals(
            null,
            batchJobs
        );

        // Queueable
        List<Audit360_JobController.JobWrapper> queueJobs =
            Audit360_JobController.getJobs('Queueable');

        System.assertNotEquals(
            null,
            queueJobs
        );

        // ScheduledApex
        List<Audit360_JobController.JobWrapper> scheduledJobs =
            Audit360_JobController.getJobs('ScheduledApex');

        System.assertNotEquals(
            null,
            scheduledJobs
        );
    }

    /*
     * --------------------------------------------
     * TEST abortJob()
     * --------------------------------------------
     */
    @isTest
    static void testAbortJob() {

        String cronExp = '0 0 12 * * ?';

        Test.startTest();

        String jobId = System.schedule(
            'Abort Test Job',
            cronExp,
            new TestScheduler()
        );

        Audit360_JobController.abortJob(jobId);

        Test.stopTest();

        System.assertNotEquals(null, jobId);
    }

    /*
     * --------------------------------------------
     * TEST rescheduleJob()
     * --------------------------------------------
     */
    @isTest
    static void testRescheduleJob() {

        Datetime dt = Datetime.now().addMinutes(10);

        Test.startTest();

        Audit360_JobController.rescheduleJob(
            'Audit360_JobControllerTest.TestScheduler',
            dt
        );

        Test.stopTest();

        List<CronTrigger> cronList = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name
            LIKE 'Audit360_JobControllerTest.TestScheduler%'
        ];

        System.assert(
            cronList.size() > 0
        );
    }
}