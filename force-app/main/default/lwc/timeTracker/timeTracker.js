import { LightningElement, track } from 'lwc';
import getTimeTrackerData from '@salesforce/apex/TimeTrackerController.getTimeTrackerData';

export default class TimeTracker extends LightningElement {

    @track headers = [];
    @track rows = [];
    @track footer = [];

    startDate;
    endDate;

    // Default project
    projectKey = 'PUL';

    grandTotal = '0h';
    isLoading = false;

    // Project Picklist
    projectOptions = [
        { label: 'PUL', value: 'PUL' },
        { label: 'NEST', value: 'NEST' }
    ];

    connectedCallback() {

        const today = new Date();
        const start = new Date();

        start.setDate(today.getDate() - 6);

        this.startDate = this.toInputDate(start);
        this.endDate = this.toInputDate(today);

        this.loadData();
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    handleStartDate(event) {
        this.startDate = event.target.value;
        this.validateDates();
    }

    handleEndDate(event) {
        this.endDate = event.target.value;
        this.validateDates();
    }

    handleProjectKey(event) {
        this.projectKey = event.detail.value;
    }

    validateDates() {

        const startInput = this.template.querySelector(
            'lightning-input[data-id="startDate"]'
        );

        if (!startInput) {
            return true;
        }

        if (
            this.startDate &&
            this.endDate &&
            this.startDate > this.endDate
        ) {
            startInput.setCustomValidity(
                'Start Date cannot be greater than End Date.'
            );
            startInput.reportValidity();
            return false;
        }

        startInput.setCustomValidity('');
        startInput.reportValidity();

        return true;
    }

    async loadData() {

        if (!this.validateDates()) {
            return;
        }

        this.isLoading = true;

        try {

            const result = await getTimeTrackerData({
                startDate: this.startDate,
                endDate: this.endDate,
                projectKey: this.projectKey
            });

            this.buildHeaders(result.headers);
            this.buildRows(result.resources);
            this.buildFooter(result.dateTotals);

            this.grandTotal = this.formatHours(result.grandTotal);

        } catch (error) {

            console.error('Error loading Jira Time Tracker', error);

        } finally {

            this.isLoading = false;

        }
    }

    buildHeaders(headers) {

        this.headers = headers.map(header => {

            return {

                key: header.dateValue,
                label: header.label,
                month: header.month,
                dayName: header.dayName,
                className: header.isWeekend
                    ? 'weekend-header'
                    : ''

            };

        });

    }

    buildRows(resources) {

        this.rows = resources.map(resource => {

            const cells = [];

            this.headers.forEach(header => {

                const value =
                    resource.hoursByDate[header.key] ?? 0;

                cells.push({

                    key: header.key,

                    value: this.formatHours(value),

                    className:
                        header.className === 'weekend-header'
                            ? 'weekend-cell'
                            : ''

                });

            });

            return {

                key: resource.resourceName,

                resourceName: resource.resourceName,

                total: this.formatHours(resource.totalHours),

                cells: cells

            };

        });

    }

    buildFooter(dateTotals) {

        this.footer = [];

        this.headers.forEach(header => {

            const value =
                dateTotals[header.key] ?? 0;

            this.footer.push({

                key: header.key,

                value: this.formatHours(value),

                className:
                    header.className === 'weekend-header'
                        ? 'weekend-cell'
                        : ''

            });

        });

    }

    formatHours(decimalHours) {

        if (decimalHours === null || decimalHours === undefined) {
            return '0h';
        }

        const totalMinutes =
            Math.round(Number(decimalHours) * 60);

        const hours =
            Math.floor(totalMinutes / 60);

        const minutes =
            totalMinutes % 60;

        if (hours === 0 && minutes === 0) {
            return '0h';
        }

        if (hours === 0) {
            return `${minutes}m`;
        }

        if (minutes === 0) {
            return `${hours}h`;
        }

        return `${hours}h ${minutes}m`;

    }

    toInputDate(date) {

        const year = date.getFullYear();

        const month =
            String(date.getMonth() + 1).padStart(2, '0');

        const day =
            String(date.getDate()).padStart(2, '0');

        return `${year}-${month}-${day}`;

    }

}