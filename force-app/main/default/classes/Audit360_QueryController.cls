public Without Sharing class Audit360_QueryController {

    private static final Integer QUERY_LIMIT = 50000;

    /* ── Wire-compatible method ─────────────────────── */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> querySetupAudit() {

        // FLS check on SetupAuditTrail fields
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.SetupAuditTrail.fields.getMap();

        // Base fields always requested
        List<String> safeFields = new List<String>{ 'Id', 'Action', 'Section', 'Display', 'CreatedDate', 'CreatedById' };
        List<String> accessible = new List<String>();
        for (String f : safeFields) {
            Schema.SObjectField sf = fieldMap.get(f.toLowerCase());
            if (sf != null && sf.getDescribe().isAccessible()) {
                accessible.add(f);
            }
        }

        // FIX 2: include CreatedBy.Name relationship field
        // This is a relationship query — FLS on User.Name checked separately
        Boolean canReadUserName =
            Schema.SObjectType.User.fields.Name.isAccessible();

        String nameField = canReadUserName ? ', CreatedBy.Name' : '';

        String soql = 'SELECT '
            + String.join(accessible, ', ')
            + nameField
            + ' FROM SetupAuditTrail'
            + ' ORDER BY CreatedDate DESC'
            + ' LIMIT ' + QUERY_LIMIT;

        List<SetupAuditTrail> rows = (List<SetupAuditTrail>) Database.query(soql);

        // Map to List<Map> so LWC can access CreatedBy.Name via row.createdByName
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (SetupAuditTrail r : rows) {
            Map<String, Object> m = new Map<String, Object>{
                'Id'          => r.Id,
                'Action'      => r.Action,
                'Section'     => r.Section,
                'Display'     => r.Display,
                'CreatedDate' => r.CreatedDate,
                'CreatedById' => r.CreatedById,
                // FIX 2: expose as a flat field for easy LWC binding
                'createdByName' => (canReadUserName && r.CreatedBy != null)
                                    ? r.CreatedBy.Name
                                    : r.CreatedById
            };
            result.add(m);
        }
        return result;
    }

    /* ── Export variant: up to 10,000 rows ──────────── */
    @AuraEnabled
    public static List<Map<String, Object>> querySetupAuditForExport(
        String sectionFilter,
        String searchTerm,
        Integer maxRows
    ) {
        Integer safeLimit = (maxRows != null && maxRows > 0 && maxRows <= 10000)
            ? maxRows : 10000;

        Boolean canReadUserName = Schema.SObjectType.User.fields.Name.isAccessible();
        String nameField = canReadUserName ? ', CreatedBy.Name' : '';

        String soql = 'SELECT Id, Action, Section, Display, CreatedDate, CreatedById'
            + nameField
            + ' FROM SetupAuditTrail'
            + ' LIMIT ' + QUERY_LIMIT;

        List<String> conditions = new List<String>();
        if (String.isNotBlank(sectionFilter)) {
            conditions.add('Section = :sectionFilter');
        }
        if (String.isNotBlank(searchTerm)) {
            String likeVal = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            conditions.add('Display LIKE :likeVal');
        }
        if (!conditions.isEmpty()) {
            soql += ' WHERE ' + String.join(conditions, ' AND ');
        }
        soql += ' ORDER BY CreatedDate DESC LIMIT ' + safeLimit;

        List<SetupAuditTrail> rows = (List<SetupAuditTrail>) Database.query(soql);

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (SetupAuditTrail r : rows) {
            result.add(new Map<String, Object>{
                'Id'            => r.Id,
                'Action'        => r.Action,
                'Section'       => r.Section,
                'Display'       => r.Display,
                'CreatedDate'   => r.CreatedDate,
                'CreatedById'   => r.CreatedById,
                'createdByName' => (canReadUserName && r.CreatedBy != null)
                                    ? r.CreatedBy.Name : r.CreatedById
            });
        }
        return result;
    }
}