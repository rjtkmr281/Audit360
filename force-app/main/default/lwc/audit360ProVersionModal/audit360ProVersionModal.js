import { LightningElement, track ,api} from 'lwc';
export default class Audit360_ProVersionModal extends LightningElement {

    @api showModal;

    // openModal() {
    //     this.showModal = true;
    // }

   closeModal() {

        this.dispatchEvent(
            new CustomEvent('closemodal')
        );
    }
}