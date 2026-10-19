import { LightningElement } from 'lwc';
import getProperties from '@salesforce/apex/MaintenanceController.getProperties';
import getRequests from '@salesforce/apex/MaintenanceController.getRequests';
import createRequest from '@salesforce/apex/MaintenanceController.createRequest';
import updateStatus from '@salesforce/apex/MaintenanceController.updateStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class MaintenanceManager extends NavigationMixin(LightningElement) {
    properties = [];
    requests = [];
    propertyId = '';
    description = '';
    saving = false;

    statusOptions = [
        { label: 'Open', value: 'Open' },
        { label: 'In Progress', value: 'In Progress' },
        { label: 'Completed', value: 'Completed' },
        { label: 'Cancelled', value: 'Cancelled' }
    ];

    connectedCallback() {
        this.refresh();
    }

    async refresh() {
        try {
            [this.properties, this.requests] = await Promise.all([
                getProperties(),
                getRequests()
            ]);
        } catch (error) {
            this.toast('Load failed', error?.body?.message || 'Unable to load maintenance data.', 'error');
        }
    }

    get propertyOptions() {
        return this.properties.map(p => ({
            label: `${p.Name} - ${p.Address__c}, ${p.City__c}`,
            value: p.Id
        }));
    }

    handleChange(event) {
        this[event.target.name] = event.detail?.value ?? event.target.value;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    async handleCreate() {
        const inputs = [...this.template.querySelectorAll('[data-form="create"]')];
        if (!inputs.every(input => input.reportValidity())) return;

        this.saving = true;
        try {
            const requestId = await createRequest({
                propertyId: this.propertyId,
                description: this.description
            });

            this.toast('Request created', 'The request was assigned to the vendor with the lowest open workload.', 'success');
            this.description = '';
            this.propertyId = '';
            await this.refresh();

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: requestId,
                    objectApiName: 'Maintenance_Request__c',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.toast('Creation failed', error?.body?.message || 'Unable to create request.', 'error');
        } finally {
            this.saving = false;
        }
    }

    async handleStatusChange(event) {
        const requestId = event.target.dataset.id;
        const newStatus = event.detail.value;
        try {
            await updateStatus({ requestId, newStatus });
            this.toast('Status updated', 'Maintenance status saved.', 'success');
            await this.refresh();
        } catch (error) {
            this.toast('Update failed', error?.body?.message || 'Unable to update status.', 'error');
        }
    }
}