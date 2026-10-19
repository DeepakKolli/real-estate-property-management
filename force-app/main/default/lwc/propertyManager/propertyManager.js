
import { LightningElement } from 'lwc';
import getProperties from '@salesforce/apex/PropertyController.getProperties';

const PAGE_SIZE = 25;

export default class PropertyManager extends LightningElement {
    properties = [];
    error;
    pageNumber = 1;
    totalRecords = 0;
    loading = false;

    propertyStatus = '';
    furnishingStatus = '';
    minRent = '';
    maxRent = '';

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalRecords / PAGE_SIZE));
    }

    get previousDisabled() {
        return this.loading || this.pageNumber <= 1;
    }

    get nextDisabled() {
        return this.loading || this.pageNumber >= this.totalPages;
    }

    get pageLabel() {
        return `Page ${this.pageNumber} of ${this.totalPages}`;
    }

    get statusOptions() {
        return [
            { label: 'All statuses', value: '' },
            { label: 'Available', value: 'Available' },
            { label: 'Occupied', value: 'Occupied' }
        ];
    }

    get furnishingOptions() {
        return [
            { label: 'All furnishing', value: '' },
            { label: 'Furnished', value: 'Furnished' },
            { label: 'Semi-Furnished', value: 'Semi-Furnished' },
            { label: 'Unfurnished', value: 'Unfurnished' }
        ];
    }

    connectedCallback() {
        this.loadProperties();
    }

    async loadProperties() {
        this.loading = true;
        this.error = undefined;

        try {
            const result = await getProperties({
                pageNumber: this.pageNumber,
                propertyStatus: this.propertyStatus || null,
                furnishingStatus: this.furnishingStatus || null,
                minRent: this.minRent === '' ? null : Number(this.minRent),
                maxRent: this.maxRent === '' ? null : Number(this.maxRent)
            });

            this.properties = result.records;
            this.totalRecords = result.totalRecords;
        } catch (e) {
            this.error = e?.body?.message || 'Unable to load properties.';
            this.properties = [];
            this.totalRecords = 0;
        } finally {
            this.loading = false;
        }
    }

    handleStatusChange(event) {
        this.propertyStatus = event.detail.value;
        this.applyFilters();
    }

    handleFurnishingChange(event) {
        this.furnishingStatus = event.detail.value;
        this.applyFilters();
    }

    handleMinRentChange(event) {
        this.minRent = event.target.value;
    }

    handleMaxRentChange(event) {
        this.maxRent = event.target.value;
    }

    applyFilters() {
        this.pageNumber = 1;
        this.loadProperties();
    }

    previousPage() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.loadProperties();
        }
    }

    nextPage() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.loadProperties();
        }
    }
}
