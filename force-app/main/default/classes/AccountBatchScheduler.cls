global class AccountBatchScheduler implements Schedulable {
    
    // Number of records to create — change this as needed
    private Integer totalRecords;
    
    // Constructor
    global AccountBatchScheduler(Integer totalRecords) {
        this.totalRecords = totalRecords;
    }
    
    // Default constructor (uses 501 records by default)
    global AccountBatchScheduler() {
        this.totalRecords = 50;
    }
    
    // Execute method — runs when the schedule fires
    global void execute(SchedulableContext sc) {
        
        // Create batch instance
        AccountBatchInsert batch = new AccountBatchInsert(totalRecords);
        
        // Fire the batch with chunk size 200
        Database.executeBatch(batch, 200);
        
        System.debug('AccountBatchInsert fired by Scheduler at: ' + DateTime.now());
    }
}