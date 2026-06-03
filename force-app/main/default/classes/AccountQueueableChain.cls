public class AccountQueueableChain implements Queueable {
    
    private Integer totalRecords;
    private Integer batchNumber;
    private Integer startIndex;
    private Integer endIndex;
    
    // Constructor
    public AccountQueueableChain(Integer totalRecords, Integer batchNumber, 
                                  Integer startIndex, Integer endIndex) {
        this.totalRecords = totalRecords;
        this.batchNumber  = batchNumber;
        this.startIndex   = startIndex;
        this.endIndex     = endIndex;
    }
    
    public void execute(QueueableContext qc) {
        
        List<Account> accountsToInsert = new List<Account>();
        
        // Create accounts for this chunk only
        for (Integer i = startIndex; i <= endIndex; i++) {
            Account acc     = new Account();
            acc.Name        = 'Chained Account ' + i;
            acc.Phone       = '7000000' + String.valueOf(i).leftPad(3, '0');
            acc.Website     = 'https://chainedaccount' + i + '.com';
            acc.Industry    = (Math.mod(i, 3) == 0) ? 'Technology' :
                              (Math.mod(i, 3) == 1) ? 'Finance' : 'Healthcare';
            acc.Type        = (Math.mod(i, 2) == 0) ? 'Customer' : 'Prospect';
            acc.Description = 'Batch #' + batchNumber + ' — Record #' + i;
            accountsToInsert.add(acc);
        }
        
        Database.insert(accountsToInsert, false);
        System.debug('Batch #' + batchNumber + ' done. Records: ' 
                     + startIndex + ' to ' + endIndex);
        
        // ── CHAINING — fire next job if records remain ──
        Integer nextStart = endIndex + 1;
        if (nextStart <= totalRecords) {
            Integer nextEnd = Math.min(nextStart + 199, totalRecords);
            System.enqueueJob(
                new AccountQueueableChain(
                    totalRecords,
                    batchNumber + 1,
                    nextStart,
                    nextEnd
                )
            );
            System.debug('Next job queued: ' + nextStart + ' to ' + nextEnd);
        } else {
            System.debug('All ' + totalRecords + ' records created successfully!');
        }
    }
}