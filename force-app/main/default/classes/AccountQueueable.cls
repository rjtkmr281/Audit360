public class AccountQueueable implements Queueable {
    
    private Integer totalRecords;
    
    // Constructor
    public AccountQueueable(Integer totalRecords) {
        this.totalRecords = totalRecords;
    }
    
    // Execute method — runs when job is picked up from queue
    public void execute(QueueableContext qc) {
        
        List<Account> accountsToInsert = new List<Account>();
        
        for (Integer i = 1; i <= totalRecords; i++) {
            Account acc        = new Account();
            acc.Name           = 'Queueable Account ' + i;
            acc.Phone          = '8000000' + String.valueOf(i).leftPad(3, '0');
            acc.Website        = 'https://queueableaccount' + i + '.com';
            acc.Industry       = (Math.mod(i, 3) == 0) ? 'Technology' :
                                 (Math.mod(i, 3) == 1) ? 'Finance' : 'Healthcare';
            acc.Type           = (Math.mod(i, 2) == 0) ? 'Customer' : 'Prospect';
            acc.Description    = 'Auto-created by Queueable Apex — Record #' + i;
            accountsToInsert.add(acc);
        }
        
        // Insert all accounts
        Database.SaveResult[] results = Database.insert(accountsToInsert, false);
        
        // Log errors if any
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('ERROR: ' + err.getMessage());
                }
            }
        }
        
        System.debug('Queueable Job complete. Accounts created: ' + totalRecords);
        System.debug('Job ID: ' + qc.getJobId());
    }
}