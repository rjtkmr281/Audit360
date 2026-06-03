public Without Sharing class Audit360_ObjectAndFieldAccessController {
    
    /*
==================================================
GET ALL OBJECTS
==================================================
*/
   @AuraEnabled(cacheable=true)
public static List<Map<String, String>> getAllObjects() {

    List<Map<String, String>> objectList =
        new List<Map<String, String>>();

    Map<String, Schema.SObjectType> globalMap =
        Schema.getGlobalDescribe();

    List<String> sortedLabels =
        new List<String>();

    Map<String, String> labelToApi =
        new Map<String, String>();

    for(String objApiName : globalMap.keySet()) {

        Schema.DescribeSObjectResult describeObj =
            globalMap.get(objApiName).getDescribe();

        String label =
            describeObj.getLabel();

        sortedLabels.add(label);

        labelToApi.put(
            label,
            objApiName
        );
    }

    sortedLabels.sort();

    for(String label : sortedLabels) {

        objectList.add(
            new Map<String, String>{
                'label' => label,
                'apiName' => labelToApi.get(label)
            }
        );
    }

    return objectList;
}
    
    /*
==================================================
GET OBJECT FIELDS
==================================================
*/
    @AuraEnabled(cacheable=true)
    public static List<FieldWrapper> getObjectFields(String objectName) {    
        List<FieldWrapper> fieldList = new List<FieldWrapper>();
        
        // CHECK OBJECT NAME
        if(String.isBlank(objectName)) {
            System.debug('Object Name is Blank');
            return fieldList;
        }
        
        // GET OBJECT
        Schema.SObjectType objType =  Schema.getGlobalDescribe().get(objectName);    
        if(objType == null) {
            System.debug('Invalid Object Name : ' + objectName);
            return fieldList;
        }
        
        // GET ALL FIELDS
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        
        for(String fieldApiName : fieldMap.keySet()) {        
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldApiName).getDescribe();
            
            FieldWrapper fw = new FieldWrapper();        
            fw.label   = dfr.getLabel();
            fw.apiName = dfr.getName();
            fw.type    = String.valueOf(dfr.getType());        
            fieldList.add(fw);
            
        }
        fieldList.sort();    
        return fieldList;
    }
    
    /*
==================================================
GET RECORD TYPE PICKLIST VALUES
==================================================
*/
    @AuraEnabled(cacheable=true)
    public static List<RecordTypePicklistWrapper> getRecordTypePicklistValues(
        String objectName,
        String fieldName
    ) {
        
        List<RecordTypePicklistWrapper> finalList =
            new List<RecordTypePicklistWrapper>();
        
        /*
==========================================
GET ALL FIELD VALUES
==========================================
*/
        
        List<String> allValues =
            new List<String>();
        
        Schema.DescribeFieldResult dfr =
            Schema.getGlobalDescribe()
            .get(objectName)
            .getDescribe()
            .fields
            .getMap()
            .get(fieldName)
            .getDescribe();
        
        for(Schema.PicklistEntry pe :
            dfr.getPicklistValues()) {
                
                allValues.add(pe.getValue());
            }
        
        /*
==========================================
GET RECORD TYPES
==========================================
*/
        
        List<RecordType> rtList = [
            SELECT Id,
            Name,
            DeveloperName
            FROM RecordType
            WHERE SobjectType = :objectName
            AND IsActive = true
        ];
        
        for(RecordType rt : rtList) {
            
            // OBJECT + FIELD + RECORD TYPE
            
            String objectApiName = objectName;
            String fieldApiName = fieldName;
            String recordTypeDevName = rt.DeveloperName;
            
            /*
==========================================
RECORD TYPE ID
==========================================
*/
            
            Id recordTypeId = Schema.getGlobalDescribe()
                .get(objectApiName)
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get(recordTypeDevName)
                .getRecordTypeId();
            
            /*
==========================================
GET PICKLIST VALUES
==========================================
*/
            
            ConnectApi.PicklistValuesCollection allPicklists =
                ConnectApi.RecordUi.getPicklistValuesByRecordType(
                    objectApiName,
                    recordTypeId
                );
            
            Map<String, ConnectApi.PicklistValues> picklistFieldsMap =
                allPicklists.picklistFieldValues;
            
            Map<String, String> recordTypePicklistMap =
                new Map<String, String>();
            
            List<String> selectedValues =
                new List<String>();
            
            List<String> unselectedValues =
                new List<String>();
            
            if(picklistFieldsMap.containsKey(fieldApiName)) {
                
                ConnectApi.PicklistValues targetPicklist =
                    picklistFieldsMap.get(fieldApiName);
                
                for(ConnectApi.PicklistValue entry :
                    targetPicklist.values) {
                        
                        recordTypePicklistMap.put(
                            entry.label,
                            entry.value
                        );
                        
                        selectedValues.add(entry.value);
                    }
            }
            
            /*
==========================================
UNSELECTED VALUES
==========================================
*/
            
            for(String val : allValues) {
                
                if(!selectedValues.contains(val)) {
                    unselectedValues.add(val);
                }
            }
            
            /*
==========================================
WRAPPER
==========================================
*/
            
            RecordTypePicklistWrapper wrap =
                new RecordTypePicklistWrapper();
            
            wrap.recordTypeName = rt.Name;
            wrap.selectedValues = selectedValues;
            wrap.unselectedValues = unselectedValues;
            wrap.totalValues = allValues.size();
            wrap.selectedCount = selectedValues.size();
            wrap.unselectedCount = unselectedValues.size();
            
            finalList.add(wrap);
            
            /*
==========================================
DEBUG
==========================================
*/
            
            System.debug(
                '--- Filtered Picklist Mapping for Record Type: '
                + recordTypeDevName +
                ' ---'
            );
            
            System.debug(
                JSON.serializePretty(recordTypePicklistMap)
            );
        }
        
        return finalList;
    }
    
    /*
==================================================
GET PERMISSION SETS
==================================================
*/
public class PermissionSetWrapper {

    @AuraEnabled
    public String permissionSetName;

    @AuraEnabled
    public Boolean readAccess;

    @AuraEnabled
    public Boolean editAccess;
}

@AuraEnabled(cacheable=true)
public static List<PermissionSetWrapper> getPermissionSets(

    String objectName,
    String fieldName
) {

    List<PermissionSetWrapper> result =
        new List<PermissionSetWrapper>();

    if(
        String.isBlank(objectName) ||
        String.isBlank(fieldName)
    ) {

        return result;
    }

    String fullField =
        objectName + '.' + fieldName;

    List<FieldPermissions> perms = [

        SELECT Parent.Label,
               PermissionsRead,
               PermissionsEdit

        FROM FieldPermissions

        WHERE Field = :fullField

        AND Parent.IsOwnedByProfile = false
    ];

    for(FieldPermissions fp : perms) {

        PermissionSetWrapper wrap =
            new PermissionSetWrapper();

        wrap.permissionSetName =
            fp.Parent.Label;

        wrap.readAccess =
            fp.PermissionsRead;

        wrap.editAccess =
            fp.PermissionsEdit;

        result.add(wrap);
    }

    return result;
}

    /*
==================================================
WRAPPERS
==================================================
*/
    
    public class FieldWrapper
        implements Comparable {
            
            @AuraEnabled
            public String label;
            
            @AuraEnabled
            public String apiName;
            
            @AuraEnabled
            public String type;
            
            public Integer compareTo(Object obj) {
                
                FieldWrapper other =
                    (FieldWrapper)obj;
                
                return label.compareTo(other.label);
            }
        }
    
    public class RecordTypePicklistWrapper {
        
        @AuraEnabled
        public String recordTypeName;
        
        @AuraEnabled
        public List<String> selectedValues;
        
        @AuraEnabled
        public List<String> unselectedValues;
        
        @AuraEnabled
        public Integer totalValues;
        
        @AuraEnabled
        public Integer selectedCount;
        
        @AuraEnabled
        public Integer unselectedCount;
    }
    @AuraEnabled(cacheable=true)
public static List<Map<String, Object>> getProfilesWithFieldAccess(
    String objectName,
    String fieldName
) {

    List<Map<String, Object>> result = new List<Map<String, Object>>();

    String fullFieldName = objectName + '.' + fieldName;

    List<FieldPermissions> fpList = [
        SELECT Id,
               Parent.Profile.Name,
               PermissionsRead,
               PermissionsEdit
        FROM FieldPermissions
        WHERE SobjectType = :objectName
        AND Field = :fullFieldName
        AND Parent.IsOwnedByProfile = true
        ORDER BY Parent.Profile.Name
    ];

    for(FieldPermissions fp : fpList) {

        Map<String, Object> row = new Map<String, Object>();

        row.put(
            'profileName',
            fp.Parent.Profile.Name
        );

        row.put(
            'readAccess',
            fp.PermissionsRead
        );

        row.put(
            'editAccess',
            fp.PermissionsEdit
        );

        result.add(row);
    }

    return result;
}
}