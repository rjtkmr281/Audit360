import { LightningElement, api } from 'lwc';
export default class Audit360_KPI extends LightningElement {

    @api kpiNumber;
    @api kpiLabel;
    @api kpiSubject;
    @api color;

    displayNumber = 0;

}