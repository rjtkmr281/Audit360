global class AccountBatchInsert implements Database.Batchable<Integer> {
    
    private Integer totalRecords;
    
    global AccountBatchInsert(Integer totalRecords) {
        this.totalRecords = totalRecords;
    }
    
    global Iterable<Integer> start(Database.BatchableContext bc) {
        List<Integer> recordNumbers = new List<Integer>();
        for (Integer i = 1; i <= totalRecords; i++) {
            recordNumbers.add(i);
        }
        return recordNumbers;
    }
    
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
        Database.SaveResult[] results = Database.insert(accountsToInsert, false);
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('ERROR: ' + err.getMessage());
                }
            }
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        System.debug('Batch Complete!');
    }
}