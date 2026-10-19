import { LightningElement } from 'lwc';
import createProperty from '@salesforce/apex/PropertyFormController.createProperty';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PropertyForm extends LightningElement {
    address = '';
    city = '';
    state = '';
    postalCode = '';
    country = '';
    propertyType = 'Residential';
    furnishingStatus = '';
    propertyStatus = 'Available';
    rent = '';
    description = '';
    documentIds = [];
    saving = false;

    get propertyTypeOptions() {
        return [
            { label: 'Residential', value: 'Residential' },
            { label: 'Commercial', value: 'Commercial' }
        ];
    }

    get furnishingOptions() {
        return [
            { label: 'Furnished', value: 'Furnished' },
            { label: 'Semi-Furnished', value: 'Semi-Furnished' },
            { label: 'Unfurnished', value: 'Unfurnished' }
        ];
    }

    get statusOptions() {
        return [
            { label: 'Available', value: 'Available' },
            { label: 'Occupied', value: 'Occupied' }
        ];
    }

    handleChange(event) {
        this[event.target.name] = event.detail?.value ?? event.target.value;
    }

    handleUploadFinished(event) {
        const uploaded = event.detail.files.map(file => file.documentId);
        this.documentIds = [...new Set([...this.documentIds, ...uploaded])];
        this.toast('Images uploaded', `${uploaded.length} file(s) uploaded.`, 'success');
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    async handleSave() {
        const fields = [...this.template.querySelectorAll(
            'lightning-input, lightning-combobox, lightning-textarea'
        )];
        if (!fields.every(field => field.reportValidity())) {
            return;
        }
        if (!this.documentIds.length) {
            this.toast('Image required', 'Upload at least one image before saving.', 'error');
            return;
        }

        this.saving = true;
        try {
            const recordId = await createProperty({
                address: this.address,
                city: this.city,
                state: this.state,
                postalCode: this.postalCode,
                country: this.country,
                propertyType: this.propertyType,
                furnishingStatus: this.furnishingStatus || null,
                propertyStatus: this.propertyStatus,
                rent: Number(this.rent),
                description: this.description,
                documentIds: this.documentIds
            });

            this.toast('Property created', `Property saved: ${recordId}`, 'success');
            this.dispatchEvent(new CustomEvent('propertycreated', {
                detail: { recordId },
                bubbles: true,
                composed: true
            }));
            this.address = '';
            this.city = '';
            this.state = '';
            this.postalCode = '';
            this.country = '';
            this.rent = '';
            this.description = '';
            this.documentIds = [];
        } catch (error) {
            this.toast(
                'Unable to save property',
                error?.body?.message || 'Check the property fields and try again.',
                'error'
            );
        } finally {
            this.saving = false;
        }
    }
}