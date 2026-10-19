import { LightningElement, api, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import JSPDF from '@salesforce/resourceUrl/jspdf';
import getLeaseDetails from '@salesforce/apex/LeasePdfController.getLeaseDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class LeasePdf extends LightningElement {
    @api recordId;
    lease;
    libraryLoaded = false;
    loading = true;

    @wire(getLeaseDetails, { leaseId: '$recordId' })
    wiredLease({ data, error }) {
        if (data) {
            this.lease = data;
            this.loading = false;
        } else if (error) {
            this.loading = false;
            this.toast('Lease load failed',
                error?.body?.message || 'Unable to load lease details.', 'error');
        }
    }

    async ensureLibrary() {
        if (!this.libraryLoaded) {
            await loadScript(this, JSPDF);
            if (!window.jspdf?.jsPDF) {
                throw new Error('jsPDF library did not load correctly.');
            }
            this.libraryLoaded = true;
        }
    }

    async handleDownload() {
        if (!this.lease) {
            this.toast('Please wait', 'Lease details are still loading.', 'warning');
            return;
        }

        try {
            await this.ensureLibrary();
            const { jsPDF } = window.jspdf;
            const pdf = new jsPDF();
            const tenant = this.lease.Tenant__r;
            const property = this.lease.Property__r;

            pdf.setFontSize(20);
            pdf.text('LEASE AGREEMENT', 20, 25);
            pdf.setFontSize(12);
            pdf.text(`Lease Number: ${this.lease.Name || ''}`, 20, 42);
            pdf.text(`Tenant: ${tenant?.Name || ''}`, 20, 54);
            pdf.text(`Tenant Email: ${tenant?.Email__c || ''}`, 20, 64);
            pdf.text(`Property: ${property?.Name || ''}`, 20, 78);

            const address = property?.Address__c || '';
            pdf.text(`Address: ${address}`, 20, 88, { maxWidth: 170 });
            pdf.text(
                `Monthly Rent: ${this.lease.Agreed_Monthly_Rent__c ?? ''}`,
                20, 105
            );
            pdf.text(`Start Date: ${this.lease.Start_Date__c || ''}`, 20, 117);
            pdf.text(`End Date: ${this.lease.End_Date__c || ''}`, 20, 129);

            pdf.setFontSize(10);
            pdf.text(
                'This document summarizes the lease details recorded in the property management system.',
                20, 150, { maxWidth: 170 }
            );
            pdf.save(`${this.lease.Name || 'Lease'} .pdf`.replace(' .pdf', '.pdf'));
            this.toast('PDF downloaded', 'Lease PDF generated successfully.', 'success');
        } catch (error) {
            this.toast('PDF generation failed',
                error?.message || 'Unable to generate the PDF.', 'error');
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}