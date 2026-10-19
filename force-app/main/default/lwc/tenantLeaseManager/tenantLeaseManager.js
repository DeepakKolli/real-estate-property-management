import { LightningElement } from 'lwc';
import getTenants from '@salesforce/apex/TenantLeaseController.getTenants';
import getAvailableProperties from '@salesforce/apex/TenantLeaseController.getAvailableProperties';
import createTenant from '@salesforce/apex/TenantLeaseController.createTenant';
import createLease from '@salesforce/apex/TenantLeaseController.createLease';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class TenantLeaseManager extends NavigationMixin(LightningElement) {
    tenants = [];
    properties = [];
    tenantName = '';
    phone = '';
    email = '';
    tenantId = '';
    propertyId = '';
    terms = '';
    agreedRent = '';
    startDate = '';
    endDate = '';
    saving = false;

    connectedCallback() {
        this.refreshData();
    }

    async refreshData() {
        try {
            [this.tenants, this.properties] = await Promise.all([
                getTenants(),
                getAvailableProperties()
            ]);
        } catch (error) {
            this.toast('Load failed', error?.body?.message || 'Unable to load data.', 'error');
        }
    }

    get tenantOptions() {
        return this.tenants.map(t => ({ label: t.Name, value: t.Id }));
    }

    get propertyOptions() {
        return this.properties.map(p => ({
            label: `${p.Name} - ${p.Address__c}, ${p.City__c} (₹${p.Rent__c})`,
            value: p.Id
        }));
    }

    handleChange(event) {
        this[event.target.name] = event.detail?.value ?? event.target.value;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    async handleCreateTenant() {
        const inputs = [...this.template.querySelectorAll('[data-section="tenant"]')];
        if (!inputs.every(input => input.reportValidity())) return;

        this.saving = true;
        try {
            const id = await createTenant({
                tenantName: this.tenantName,
                phone: this.phone,
                email: this.email
            });
            this.toast('Tenant created', 'Tenant saved successfully.', 'success');
            this.tenantName = '';
            this.phone = '';
            this.email = '';
            await this.refreshData();
            this.tenantId = id;
        } catch (error) {
            this.toast('Tenant creation failed', error?.body?.message || 'Please check the details.', 'error');
        } finally {
            this.saving = false;
        }
    }

    async handleCreateLease() {
        const inputs = [...this.template.querySelectorAll('[data-section="lease"]')];
        if (!inputs.every(input => input.reportValidity())) return;

        this.saving = true;
        try {
            const leaseId = await createLease({
                tenantId: this.tenantId,
                propertyId: this.propertyId,
                terms: this.terms,
                agreedRent: Number(this.agreedRent),
                startDate: this.startDate,
                endDate: this.endDate
            });

            this.toast('Lease created', 'Lease saved and onboarding Task created.', 'success');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: leaseId,
                    objectApiName: 'Lease_Agreement__c',
                    actionName: 'view'
                }
            });

            this.terms = '';
            this.agreedRent = '';
            this.startDate = '';
            this.endDate = '';
            this.propertyId = '';
            await this.refreshData();
        } catch (error) {
            this.toast('Lease creation failed', error?.body?.message || 'Please check the lease details.', 'error');
        } finally {
            this.saving = false;
        }
    }
}
