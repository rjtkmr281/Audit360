global class batchSidd360 implements Database.Batchable<Integer> {
    
    private Integer totalRecords;
    
    global batchSidd360(Integer totalRecords) {
        this.totalRecords = totalRecords;
    }
    
    // Start — generate a list of numbers (1 to totalRecords)
    global Iterable<Integer> start(Database.BatchableContext bc) {
        List<Integer> recordNumbers = new List<Integer>();
        for (Integer i = 1; i <= totalRecords; i++) {
            recordNumbers.add(i);
        }
        return recordNumbers;
    }
    
    // Execute — runs per chunk (default 200 records at a time)
    global void execute(Database.BatchableContext bc, List<Integer> scope) {
        List<Account> accountsToInsert = new List<Account>();
        
        for (Integer i : scope) {
            Account acc = new Account();
            acc.Name        = 'Batch Account ' + i;
            acc.Phone       = '9000000' + String.valueOf(i).leftPad(3, '0');
            acc.Website     = 'https://batchaccount' + i + '.com';
            acc.Industry    = (Math.mod(i, 3) == 0) ? 'Technology' :
                              (Math.mod(i, 3) == 1) ? 'Finance' : 'Healthcare';
            acc.Type        = (Math.mod(i, 2) == 0) ? 'Customer' : 'Prospect';
            acc.Description = 'Auto-created by Batch Apex — Record #' + i;
            accountsToInsert.add(acc);
        }
        
        // Use Database.insert for partial success (won't stop on single failure)
        Database.SaveResult[] results = Database.insert(accountsToInsert, false);
        
        // Log any failures
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('ERROR inserting account: ' + err.getMessage());
                }
            }
        }
    }
    
    // Finish — runs once after all batches complete
    global void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, 
                   JobItemsProcessed, TotalJobItems
            FROM   AsyncApexJob
            WHERE  Id = :bc.getJobId()
        ];
        
        System.debug('====== BATCH JOB COMPLETE ======');
        System.debug('Status            : ' + job.Status);
        System.debug('Total Batches     : ' + job.TotalJobItems);
        System.debug('Batches Processed : ' + job.JobItemsProcessed);
        System.debug('Total Errors      : ' + job.NumberOfErrors);
    }
}