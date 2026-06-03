import { LightningElement, track } from 'lwc';
import getAllObjects from '@salesforce/apex/Audit360_ObjectAndFieldAccessController.getAllObjects';
import getObjectFields from '@salesforce/apex/Audit360_ObjectAndFieldAccessController.getObjectFields';
import getRecordTypePicklistValues from '@salesforce/apex/Audit360_ObjectAndFieldAccessController.getRecordTypePicklistValues';
import getPermissionSets from '@salesforce/apex/Audit360_ObjectAndFieldAccessController.getPermissionSets';
import getProfilesWithFieldAccess from '@salesforce/apex/Audit360_ObjectAndFieldAccessController.getProfilesWithFieldAccess';

export default class Audit360FieldAccessAndTracking extends LightningElement {
   @track profileColumns = [
        {
            label: 'Profile Name',
            fieldName: 'profileName',
            type: 'text'
        },
        {
            label: 'Read Access',
            fieldName: 'readAccess',
            type: 'boolean'
        },
        {
            label: 'Edit Access',
            fieldName: 'editAccess',
            type: 'boolean'
        }
    ];
    @track permissionSetColumns = [
        {
            label: 'Permission Set Name',
            fieldName: 'permissionSetName',
            type: 'text'
        },
        {
            label: 'Read Access',
            fieldName: 'readAccess',
            type: 'boolean'
        },
        {
            label: 'Edit Access',
            fieldName: 'editAccess',
            type: 'boolean'
        }
    ];
    @track objectOptions = [];
    @track fieldOptions = [];
    @track recordTypeData = [];
    @track permissionSets = [];
    @track pageLayouts = [];
    @track isLoading = false;
    selectedObject;
    selectedField;
    selectedFieldType;
    connectedCallback() {
        this.loadObjects();
    }
    loadObjects() {
        this.isLoading = true;
        getAllObjects()
            .then(result => {
                this.objectOptions =
                    result.map(obj => {
                        return {
                            label: obj.label + ' (' + obj.apiName + ')',
                            value: obj.apiName
                        };
                    });
            })
            .catch(error => {
                console.error('OBJECT ERROR === ', JSON.stringify(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedField = null;
        this.selectedFieldType = null;
        this.recordTypeData = [];
        this.permissionSets = [];
        this.pageLayouts = [];
        this.fieldOptions = [];
        this.loadFields();
    }

    loadFields() {
        this.isLoading = true;
        getObjectFields({ objectName: this.selectedObject })
            .then(result => {
                this.fieldOptions =
                    result.map(field => {
                        return {
                            label: field.label + ' (' + field.type + ')',
                            value: field.apiName,

                            apiName:
                                field.apiName,

                            type:
                                field.type
                        };
                    });
            })
            .catch(error => {

                console.error(
                    'FIELD ERROR === ',
                    JSON.stringify(error)
                );
            })

            .finally(() => {

                this.isLoading = false;
            });
    }

    handleFieldChange(event) {

    let selectedFieldObj =
        this.fieldOptions.find(
            item => item.value === event.detail.value
        );

    if (!selectedFieldObj) {
        return;
    }

    this.selectedField = selectedFieldObj.apiName;
    this.selectedFieldType = selectedFieldObj.type;

    this.loadProfiles();

    this.loadPermissionSets();

    if (this.selectedFieldType === 'PICKLIST') {
        this.loadRecordTypes();
    } else {
        this.recordTypeData = [];
    }
}
    loadRecordTypes() {
        this.isLoading = true;
        getRecordTypePicklistValues({
            objectName: this.selectedObject,
            fieldName: this.selectedField
        })
            .then(result => {
                this.recordTypeData =
                    result;
            })
            .catch(error => {
                console.error(
                    'RECORD TYPE ERROR === ',
                    JSON.stringify(error)
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    loadPermissionSets() {
        getPermissionSets({
            objectName: this.selectedObject,
            fieldName: this.selectedField
        })
            .then(result => {
                this.permissionSets = result;
                console.log('------151----',JSON.stringify(this.permissionSets))
            })
            .catch(error => {
                console.error(
                    'PERMISSION ERROR === ',
                    JSON.stringify(error)
                );
            });
    }
    @track profileAccessData = [];

loadProfiles() {

    getProfilesWithFieldAccess({
        objectName: this.selectedObject,
        fieldName: this.selectedField
    })
    .then(result => {

        console.log(
            'PROFILE ACCESS === ',
            JSON.stringify(result)
        );

        this.profileAccessData = result;
    })
    .catch(error => {

        console.error(
            'PROFILE ERROR === ',
            JSON.stringify(error)
        );
    });
}
}