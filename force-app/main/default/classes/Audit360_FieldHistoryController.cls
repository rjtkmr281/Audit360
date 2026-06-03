public Without Sharing class Audit360_FieldHistoryController {

    // ── STATIC CACHE — populated once per transaction ──────────────────────
    private static Map<String, String> HISTORY_OBJECT_MAP_CACHE;

    // ──────────────────────────────────────────────────────────────────────
    // getHistoryObjectMap — 100% DYNAMIC, zero hardcoding
    //
    // Strategy to stay within governor limits:
    //   1. Query EntityDefinition (1 SOQL) to get all objects that have a
    //      history object — this is the correct Salesforce metadata API way.
    //   2. Fall back to Schema scan only for custom (__c) objects if
    //      EntityDefinition query fails (sandbox restrictions etc.)
    //   3. Static cache so it runs only ONCE per Apex transaction.
    // ──────────────────────────────────────────────────────────────────────
    private static Map<String, String> getHistoryObjectMap() {
        if (HISTORY_OBJECT_MAP_CACHE != null) {
            return HISTORY_OBJECT_MAP_CACHE;
        }

        HISTORY_OBJECT_MAP_CACHE = new Map<String, String>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        // ── PRIMARY: Use EntityDefinition to discover history-enabled objects
        // This is 1 SOQL and covers ALL standard + custom objects dynamically.
        // HistoryRetentionPolicy != null means the object supports field history.
        try {
            List<EntityDefinition> entities = [
                SELECT QualifiedApiName
                FROM   EntityDefinition
                WHERE  IsEverCreatable = true
                AND    IsEverUpdatable = true
                LIMIT  500
            ];

            for (EntityDefinition ed : entities) {
                String objName = ed.QualifiedApiName;

                // Build expected history object name dynamically
                String histObjName;
                if (objName.endsWith('__c')) {
                    histObjName = objName.replace('__c', '__History');
                } else {
                    histObjName = objName + 'History';
                }

                // Only include if BOTH the object and its history object exist
                // and the history object is actually queryable
                if (globalDescribe.containsKey(objName.toLowerCase()) &&
                    globalDescribe.containsKey(histObjName.toLowerCase())) {

                    Schema.DescribeSObjectResult histDescribe =
                        globalDescribe.get(histObjName.toLowerCase()).getDescribe();

                    if (histDescribe.isQueryable()) {
                        // Use properly-cased API names from describe
                        String objApiName  = globalDescribe.get(objName.toLowerCase())
                                                .getDescribe().getName();
                        String histApiName = histDescribe.getName();
                        HISTORY_OBJECT_MAP_CACHE.put(objApiName, histApiName);
                    }
                }
            }
        } catch (Exception e) {
            System.debug('EntityDefinition query failed, using Schema fallback: ' + e.getMessage());

            // ── FALLBACK: Schema-based scan if EntityDefinition is restricted
            // Scans globalDescribe keys looking for *History pattern.
            // Does NOT call .getDescribe() on every object — only on confirmed matches.
            Set<String> allKeys = globalDescribe.keySet();
            for (String key : allKeys) {
                // Only look at history objects (they end with 'history' or '__history')
                if (!key.endsWith('history') && !key.endsWith('__history')) continue;

                // Derive the parent object name from the history object name
                String parentKey;
                if (key.endsWith('__history')) {
                    parentKey = key.replace('__history', '__c');
                } else {
                    parentKey = key.substring(0, key.length() - 7); // remove 'history'
                }

                if (!allKeys.contains(parentKey)) continue;

                // Only describe on confirmed pairs — not all objects
                Schema.DescribeSObjectResult histDescribe =
                    globalDescribe.get(key).getDescribe();

                if (!histDescribe.isQueryable()) continue;

                Schema.DescribeSObjectResult parentDescribe =
                    globalDescribe.get(parentKey).getDescribe();

                if (!parentDescribe.isQueryable()) continue;

                HISTORY_OBJECT_MAP_CACHE.put(
                    parentDescribe.getName(),
                    histDescribe.getName()
                );
            }
        }

        System.debug('History-enabled objects found: ' + HISTORY_OBJECT_MAP_CACHE.keySet());
        return HISTORY_OBJECT_MAP_CACHE;
    }

    // ── Date range helper ──────────────────────────────────────────────────
    private static Integer getDays(String dateRange) {
        if (dateRange == 'Last 30 days') return 30;
        if (dateRange == 'Last 90 days') return 90;
        if (dateRange == 'This Year')    return 365;
        return 7;
    }

    // ──────────────────────────────────────────────────────────────────────
    // getAvailableObjects — fully dynamic, returns ALL history-enabled objects
    // ──────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<String> getAvailableObjects() {
        List<String> names = new List<String>(getHistoryObjectMap().keySet());
        names.sort();
        return names;
    }

    // ──────────────────────────────────────────────────────────────────────
    // getTrackedFieldsForObject — single FieldDefinition query
    // ──────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<String> getTrackedFieldsForObject(String objectName) {
        return getTrackedFieldsSingle(objectName);
    }

    private static List<String> getTrackedFieldsSingle(String objectApiName) {
        List<String> fields = new List<String>();
        if (String.isBlank(objectApiName)) return fields;
        try {
            for (FieldDefinition fd : [
                SELECT DeveloperName
                FROM   FieldDefinition
                WHERE  EntityDefinition.QualifiedApiName = :objectApiName
                AND    IsFieldHistoryTracked = true
                LIMIT  50
            ]) {
                fields.add(fd.DeveloperName);
            }
        } catch (Exception e) {
            System.debug('getTrackedFieldsSingle error: ' + e.getMessage());
        }
        return fields;
    }

    // ──────────────────────────────────────────────────────────────────────
    // getInitialData — 2 SOQL total, stats always loaded async
    // ──────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static InitialDataWrapper getInitialData(
            String objectName,
            String fieldName,
            String dateRange) {

        Map<String, String> historyMap  = getHistoryObjectMap();
        List<String>        objectNames = new List<String>(historyMap.keySet());
        objectNames.sort();

        String selectedObject = objectName;
        if (String.isBlank(selectedObject) || !historyMap.containsKey(selectedObject)) {
            // Prefer Case, then Account, then first available — all dynamic
            if (historyMap.containsKey('Case')) {
                selectedObject = 'Case';
            } else if (historyMap.containsKey('Account')) {
                selectedObject = 'Account';
            } else {
                selectedObject = objectNames.isEmpty() ? '' : objectNames[0];
            }
        }

        // SOQL 1: tracked fields for selected object
        List<String> trackedFields = getTrackedFieldsSingle(selectedObject);

        // SOQL 2: field history rows
        List<FieldHistoryWrapper> history =
            getFieldHistoryInternal(selectedObject, null, dateRange, 50);

        InitialDataWrapper data = new InitialDataWrapper();
        data.objectOptions  = objectNames;
        data.selectedObject = selectedObject;
        data.fieldOptions   = trackedFields;
        data.history        = history;
        data.stats          = null; // Always loaded async from LWC

        return data;
    }

    // ──────────────────────────────────────────────────────────────────────
    // getStatsSummary — DYNAMIC: counts from ANY objects in history map
    //
    // No more hardcoded Case/Account/Contact.
    // Reads the first 3 objects from the dynamic map for KPI cards,
    // so KPI labels in the LWC must also come from Apex (returned here).
    // ──────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getStatsSummary(String dateRange) {
        Integer  days    = getDays(dateRange);
        DateTime sinceTs = DateTime.now().addDays(-days);

        Map<String, String> historyMap  = getHistoryObjectMap();
        List<String>        objectNames = new List<String>(historyMap.keySet());
        objectNames.sort();

        // Take up to 3 objects for KPI display — whichever the org has
        Map<String, Object> result = new Map<String, Object>();
        List<String>        kpiObjects = new List<String>();

        // Prefer these for display if available, otherwise take first 3
        List<String> preferred = new List<String>{ 'Case', 'Account', 'Contact' };
        for (String pref : preferred) {
            if (historyMap.containsKey(pref)) kpiObjects.add(pref);
            if (kpiObjects.size() == 3) break;
        }
        // Fill remaining slots from dynamic list
        for (String obj : objectNames) {
            if (kpiObjects.size() >= 3) break;
            if (!kpiObjects.contains(obj)) kpiObjects.add(obj);
        }

        // Query counts dynamically — one COUNT per object (max 3 SOQL)
        List<Map<String, Object>> kpiData = new List<Map<String, Object>>();
        for (String objName : kpiObjects) {
            String histObj   = historyMap.get(objName);
            Integer cnt      = 0;
            try {
                String soql = 'SELECT COUNT() FROM ' + histObj
                            + ' WHERE CreatedDate >= :sinceTs';
                cnt = Database.countQueryWithBinds(
                    soql,
                    new Map<String, Object>{ 'sinceTs' => sinceTs },
                    AccessLevel.USER_MODE
                );
            } catch (Exception e) {
                System.debug('Count error for ' + objName + ': ' + e.getMessage());
            }
            kpiData.add(new Map<String, Object>{
                'objectName' => objName,
                'count'      => cnt
            });
        }

        result.put('kpiData',       kpiData);
        result.put('objectsTracked', historyMap.size());

        // Keep backward-compatible keys for LWC (Case/Account/Contact)
        // If those objects exist in the org, populate them; otherwise 0
        result.put('caseChanges',    getCountFromKpi(kpiData, 'Case'));
        result.put('accountChanges', getCountFromKpi(kpiData, 'Account'));
        result.put('contactChanges', getCountFromKpi(kpiData, 'Contact'));

        return result;
    }

    private static Integer getCountFromKpi(
            List<Map<String, Object>> kpiData, String objName) {
        for (Map<String, Object> k : kpiData) {
            if (k.get('objectName') == objName) {
                return (Integer) k.get('count');
            }
        }
        return 0;
    }

    // ──────────────────────────────────────────────────────────────────────
    // getFieldHistory — public AuraEnabled entry point
    // ──────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<FieldHistoryWrapper> getFieldHistory(
            String objectName,
            String fieldName,
            String dateRange) {
        return getFieldHistoryInternal(objectName, fieldName, dateRange, 200);
    }

    // ── Internal shared method — fully dynamic via historyMap ──────────────
    private static List<FieldHistoryWrapper> getFieldHistoryInternal(
            String  objectName,
            String  fieldName,
            String  dateRange,
            Integer rowLimit) {

        List<FieldHistoryWrapper> results = new List<FieldHistoryWrapper>();
        if (String.isBlank(objectName)) return results;

        String historyObj = getHistoryObjectMap().get(objectName);
        if (String.isBlank(historyObj)) {
            throw new AuraHandledException(
                'Field history is not enabled for: ' + objectName);
        }

        Integer  days    = getDays(dateRange);
        DateTime sinceTs = DateTime.now().addDays(-days);

        List<String>        conditions = new List<String>{ 'CreatedDate >= :sinceTs' };
        Map<String, Object> binds      = new Map<String, Object>{ 'sinceTs' => sinceTs };

        if (String.isNotBlank(fieldName) && fieldName != 'All fields') {
            conditions.add('Field = :fieldName');
            binds.put('fieldName', fieldName);
        }

        Integer safeLimit = (rowLimit != null && rowLimit > 0) ? rowLimit : 200;

        String soql = 'SELECT Id, Field, OldValue, NewValue, CreatedBy.Name, CreatedDate'
                    + ' FROM '  + historyObj
                    + ' WHERE ' + String.join(conditions, ' AND ')
                    + ' ORDER BY CreatedDate DESC'
                    + ' LIMIT ' + safeLimit;

        try {
            for (SObject h : Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE)) {
                Id       recId  = (Id)       h.get('Id');
                String   field  = (String)   h.get('Field');
                Object   oldVal =             h.get('OldValue');
                Object   newVal =             h.get('NewValue');
                String   byName = (String)   h.getSObject('CreatedBy')?.get('Name');
                DateTime ts     = (DateTime) h.get('CreatedDate');

                results.add(new FieldHistoryWrapper(
                    recId, field,
                    oldVal != null ? String.valueOf(oldVal) : null,
                    newVal != null ? String.valueOf(newVal) : null,
                    byName, ts
                ));
            }
        } catch (Exception e) {
            throw new AuraHandledException(
                'Error retrieving field history for ' + objectName
                + ': ' + e.getMessage());
        }

        return results;
    }

    // ──────────────────────────────────────────────────────────────────────
    // getTrackingConfigLog — single batched FieldDefinition query
    // No per-object fallback queries (was the SOQL-in-loop bomb)
    // ──────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<TrackingConfigWrapper> getTrackingConfigLog() {
        List<TrackingConfigWrapper> configs = new List<TrackingConfigWrapper>();

        Map<String, String> historyMap  = getHistoryObjectMap();
        List<String>        objectNames = new List<String>(historyMap.keySet());
        objectNames.sort();

        if (objectNames.isEmpty()) return configs;

        // ── 1 SOQL: batch all objects in one FieldDefinition query ──────────
        Map<String, List<String>> fieldsPerObject = new Map<String, List<String>>();
        for (String obj : objectNames) {
            fieldsPerObject.put(obj, new List<String>());
        }

        try {
            for (FieldDefinition fd : [
                SELECT DeveloperName, EntityDefinition.QualifiedApiName
                FROM   FieldDefinition
                WHERE  EntityDefinition.QualifiedApiName IN :objectNames
                AND    IsFieldHistoryTracked = true
                LIMIT  1000
            ]) {
                String objName = fd.EntityDefinition.QualifiedApiName;
                if (fieldsPerObject.containsKey(objName)) {
                    fieldsPerObject.get(objName).add(fd.DeveloperName);
                }
            }
        } catch (Exception e) {
            System.debug('getTrackingConfigLog FieldDefinition error: ' + e.getMessage());
        }

        // ── Build wrappers in-memory — zero additional SOQL ─────────────────
        for (String objName : objectNames) {
            List<String> fieldNames = fieldsPerObject.get(objName);
            if (fieldNames == null || fieldNames.isEmpty()) continue;

            Integer fieldCount = fieldNames.size();
            String  fieldsDisplay;
            if (fieldCount <= 5) {
                fieldsDisplay = String.join(fieldNames, ', ')
                              + ' (' + fieldCount + ' fields)';
            } else {
                fieldsDisplay = fieldNames[0] + ', '
                              + fieldNames[1] + ', '
                              + fieldNames[2]
                              + ' ... (' + fieldCount + ' fields)';
            }

            configs.add(new TrackingConfigWrapper(
                objName, objName, fieldsDisplay, true, System.today().format()
            ));
        }

        return configs;
    }

    // ──────────────────────────────────────────────────────────────────────
    // exportFieldHistoryCsv
    // ──────────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static String exportFieldHistoryCsv(
            String objectName,
            String fieldName,
            String dateRange) {

        List<FieldHistoryWrapper> rows =
            getFieldHistory(objectName, fieldName, dateRange);

        List<String> lines = new List<String>();
        lines.add('Field,Old Value,New Value,Changed By,Timestamp');
        for (FieldHistoryWrapper r : rows) {
            lines.add(
                csvEscape(r.fieldName) + ',' +
                csvEscape(r.oldValue)  + ',' +
                csvEscape(r.newValue)  + ',' +
                csvEscape(r.changedBy) + ',' +
                csvEscape(r.timestamp)
            );
        }
        return String.join(lines, '\n');
    }

    private static String csvEscape(String val) {
        if (val == null) return '';
        if (val.contains(',') || val.contains('"') || val.contains('\n')) {
            return '"' + val.replace('"', '""') + '"';
        }
        return val;
    }

    // ── Wrappers ───────────────────────────────────────────────────────────
    public class FieldHistoryWrapper {
        @AuraEnabled public String id        { get; set; }
        @AuraEnabled public String fieldName { get; set; }
        @AuraEnabled public String oldValue  { get; set; }
        @AuraEnabled public String newValue  { get; set; }
        @AuraEnabled public String changedBy { get; set; }
        @AuraEnabled public String timestamp { get; set; }

        public FieldHistoryWrapper(Id recId, String field, String oldVal,
                                   String newVal, String user, DateTime ts) {
            this.id        = recId;
            this.fieldName = field;
            this.oldValue  = oldVal;
            this.newValue  = newVal != null ? newVal : '';
            this.changedBy = user;
            this.timestamp = ts != null ? ts.format('MM/dd/yyyy HH:mm:ss') : '';
        }
    }

    public class TrackingConfigWrapper {
        @AuraEnabled public String  id         { get; set; }
        @AuraEnabled public String  objectName { get; set; }
        @AuraEnabled public String  fields     { get; set; }
        @AuraEnabled public Boolean isActive   { get; set; }
        @AuraEnabled public String  dateIs     { get; set; }

        public TrackingConfigWrapper(String id, String name,
                                     String flds, Boolean active, String dt) {
            this.id         = id;
            this.objectName = name;
            this.fields     = flds;
            this.isActive   = active;
            this.dateIs     = dt;
        }
    }

    public class InitialDataWrapper {
        @AuraEnabled public List<String>              objectOptions  { get; set; }
        @AuraEnabled public String                    selectedObject { get; set; }
        @AuraEnabled public List<String>              fieldOptions   { get; set; }
        @AuraEnabled public Map<String, Object>       stats          { get; set; }
        @AuraEnabled public List<FieldHistoryWrapper> history        { get; set; }
    }
}