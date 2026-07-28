import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getTimeByUserStory from '@salesforce/apex/TimeTrackerController.getTimeByUserStory';

export default class StoryTimeTracker extends LightningElement {

    @track headers = [];
    @track rows = [];
    @track footer = [];

    startDate;
    endDate;

    // Default project
    projectKey = '';

    // Will be populated later via navigation from PUL-15
    resourceName = '';

    grandTotal = '0h';
    isLoading = false;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {

        if (!currentPageReference?.state) {
            return;
        }
        console.log('Hi' + JSON.stringify(currentPageReference.state));
        const state = currentPageReference.state;

        this.resourceName = state.c__resourceName || '';
        this.projectKey = state.c__projectKey || 'PUL';
        this.startDate = state.c__startDate || this.startDate;
        this.endDate = state.c__endDate || this.endDate;

        this.loadData();
    }

    connectedCallback() {

        if (!this.startDate || !this.endDate) {

            const today = new Date();
            const start = new Date();

            start.setDate(today.getDate() - 6);

            this.startDate = this.toInputDate(start);
            this.endDate = this.toInputDate(today);
        }

        // Allow the @wire(CurrentPageReference)
        // to populate values before loading data.
        setTimeout(() => {
            this.loadData();
        }, 0);

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

            const result = await getTimeByUserStory({
                startDate: this.startDate,
                endDate: this.endDate,
                projectKey: this.projectKey,
                resourceName: this.resourceName
            });

            this.buildHeaders(result.headers);
            this.buildRows(result.stories);
            this.buildFooter(result.dateTotals);

            this.grandTotal = this.formatHours(result.grandTotal);

        } catch (error) {

            console.error('Error loading Story Time Tracker', error);

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

    buildRows(stories) {

        this.rows = stories.map(story => {

            const cells = [];

            this.headers.forEach(header => {

                const value =
                    story.hoursByDate[header.key] ?? 0;

                const rawEntries =
                    story.entriesByDate?.[header.key] ?? [];

                const entries = rawEntries.map((entry, index) => {

                    return {
                        key: `${story.issueKey}-${header.key}-${index}`,
                        displayTime: entry.displayTime,
                        timeSpentDisplay: entry.timeSpentDisplay,
                        comment: entry.comment,
                        hasComment:
                            !!entry.comment && entry.comment.trim().length > 0
                    };

                });

                cells.push({

                    key: `${story.issueKey}-${header.key}`,

                    value:
                        Number(value) === 0
                            ? ''
                            : this.formatHours(value),

                    className:
                        header.className === 'weekend-header'
                            ? 'weekend-cell'
                            : '',

                    entries: entries,

                    hasEntries: entries.length > 0,

                    showTooltip: false

                });

            });

            return {

                key: story.issueKey,

                issueKey: story.issueKey,

                issueSummary: story.issueSummary,

                total: this.formatHours(story.totalHours),

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

    handleCellMouseEnter(event) {

        const key = event.currentTarget.dataset.key;
        const rect = event.currentTarget.getBoundingClientRect();

        const tooltipWidth = 340;
        const viewportWidth = window.innerWidth;
        const viewportHeight = window.innerHeight;

        // Center horizontally on the cell, clamped so it stays on-screen.
        let left = rect.left + (rect.width / 2);
        left = Math.min(
            Math.max(left, (tooltipWidth / 2) + 8),
            viewportWidth - (tooltipWidth / 2) - 8
        );

        // Prefer opening upward; fall back to downward if there isn't
        // enough room above the cell (e.g. first row near the top).
        const spaceAbove = rect.top;
        const openUpward = spaceAbove > 150;

        let tooltipStyle;

        if (openUpward) {
            tooltipStyle =
                `position:fixed; left:${left}px; top:${rect.top - 8}px; ` +
                `transform: translate(-50%, -100%);`;
        } else {
            tooltipStyle =
                `position:fixed; left:${left}px; top:${rect.bottom + 8}px; ` +
                `transform: translateX(-50%);`;
        }

        this.rows = this.rows.map(row => ({
            ...row,
            cells: row.cells.map(cell => {

                if (cell.key !== key || !cell.hasEntries) {
                    return cell;
                }

                return { ...cell, showTooltip: true, tooltipStyle };

            })
        }));

    }

    handleCellMouseLeave(event) {

        const key = event.currentTarget.dataset.key;

        this.rows = this.rows.map(row => ({
            ...row,
            cells: row.cells.map(cell =>
                cell.key === key
                    ? { ...cell, showTooltip: false }
                    : cell
            )
        }));

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