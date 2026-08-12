import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getActiveClients from '@salesforce/apex/TimesheetController.getActiveClients';
import getActiveProjects from '@salesforce/apex/TimesheetController.getActiveProjects';
import getTimeEntries from '@salesforce/apex/TimesheetController.getTimeEntries';
import saveTimeEntries from '@salesforce/apex/TimesheetController.saveTimeEntries';
import deleteProjectEntries from '@salesforce/apex/TimesheetController.deleteProjectEntries';

export default class TimesheetApp extends LightningElement {
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (this._recordId && this.selectedMonth) {
            this.loadExistingTimeEntries();
        }
    }

    selectedMonth; // Format 'YYYY-MM'
    selectedClientId = '';
    selectedProjectId = '';

    clientOptions = [];
    projectOptions = [];

    @track monthDays = []; 
    @track matrixRows = []; 
    @track columnTotals = []; 
    grandTotal = '0.00';
    
    // Key: `${projectId}_${date}`, Value: `Time_Log_Entry__c.Id`
    existingEntryIds = new Map();

    connectedCallback() {
        const today = new Date();
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        this.selectedMonth = `${year}-${month}`;
        
        this.generateMonthDays();

        if (this._recordId) {
            this.loadExistingTimeEntries();
        }
    }

    generateMonthDays() {
        const [year, month] = this.selectedMonth.split('-').map(Number);
        const daysInMonth = new Date(year, month, 0).getDate();
        const days = [];
        const dayNames = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

        for (let day = 1; day <= daysInMonth; day++) {
            const dateObj = new Date(year, month - 1, day);
            const dayOfWeekIndex = dateObj.getDay();
            const isWeekend = dayOfWeekIndex === 0 || dayOfWeekIndex === 6;

            const formattedDate = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;

            days.push({
                date: formattedDate,
                dayNumber: day,
                dayOfWeek: dayNames[dayOfWeekIndex],
                isWeekend: isWeekend,
                cellClass: isWeekend ? 'weekend-cell' : 'weekday-cell'
            });
        }
        this.monthDays = days;
    }

    async loadExistingTimeEntries() {
        if (!this._recordId || !this.selectedMonth) return;

        const [year, month] = this.selectedMonth.split('-').map(Number);
        const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
        const lastDay = new Date(year, month, 0).getDate();
        const endDate = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;

        try {
            const entries = await getTimeEntries({ 
                contactId: this._recordId, 
                startDate: startDate, 
                endDate: endDate 
            });
            
            this.buildMatrixFromEntries(entries);
        } catch (error) {
            this.showToast('Error', 'Error loading time entries: ' + (error.body?.message || error), 'error');
        }
    }

    buildMatrixFromEntries(entries) {
        const projectMap = new Map();
        this.existingEntryIds.clear();

        entries.forEach(entry => {
            const key = `${entry.Project__c}_${entry.Date__c}`;
            this.existingEntryIds.set(key, entry.Id);

            if (!projectMap.has(entry.Project__c)) {
                projectMap.set(entry.Project__c, {
                    projectId: entry.Project__c,
                    projectName: entry.Project__r ? entry.Project__r.Name : 'Project',
                    entriesByDate: {}
                });
            }
            projectMap.get(entry.Project__c).entriesByDate[entry.Date__c] = entry.Hours__c;
        });

        const rows = [];
        projectMap.forEach(project => {
            const days = this.monthDays.map(dayInfo => ({
                ...dayInfo,
                hours: project.entriesByDate[dayInfo.date] !== undefined ? String(project.entriesByDate[dayInfo.date]) : ''
            }));

            rows.push({
                projectId: project.projectId,
                projectName: project.projectName,
                days: days,
                rowTotal: '0.00'
            });
        });

        this.matrixRows = rows;
        this.recalculateTotals();
    }

    @wire(getActiveClients)
    wiredClients({ error, data }) {
        if (data) {
            this.clientOptions = data.map(c => ({ label: c.Name, value: c.Id }));
        }
    }

    @wire(getActiveProjects, { clientId: '$selectedClientId' })
    wiredProjects({ error, data }) {
        if (data) {
            this.projectOptions = data.map(p => ({ label: p.Name, value: p.Id }));
        }
    }

    handleMonthChange(event) {
        this.selectedMonth = event.target.value;
        this.generateMonthDays();
        this.loadExistingTimeEntries();
    }

    handleClientChange(event) {
        this.selectedClientId = event.detail.value;
        this.selectedProjectId = '';
        this.projectOptions = [];
    }

    handleProjectChange(event) {
        this.selectedProjectId = event.detail.value;
    }

    handleAddProject() {
        if (!this.selectedProjectId) return;

        const exists = this.matrixRows.some(row => row.projectId === this.selectedProjectId);
        if (exists) {
            this.showToast('Warning', 'Project is already added to the timesheet.', 'warning');
            return;
        }

        const selectedProjectObj = this.projectOptions.find(p => p.value === this.selectedProjectId);

        const newRow = {
            projectId: this.selectedProjectId,
            projectName: selectedProjectObj ? selectedProjectObj.label : 'Project',
            rowTotal: '0.00',
            days: this.monthDays.map(dayInfo => ({
                ...dayInfo,
                hours: ''
            }))
        };

        this.matrixRows = [...this.matrixRows, newRow];
        this.recalculateTotals();
    }

    async handleRemoveProject(event) {
        const projectIdToRemove = event.target.dataset.id;
        const [year, month] = this.selectedMonth.split('-').map(Number);
        const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
        const lastDay = new Date(year, month, 0).getDate();
        const endDate = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;

        try {
            await deleteProjectEntries({
                contactId: this._recordId,
                projectId: projectIdToRemove,
                startDate: startDate,
                endDate: endDate
            });

            this.matrixRows = this.matrixRows.filter(row => row.projectId !== projectIdToRemove);
            this.recalculateTotals();
            this.showToast('Success', 'Project entries deleted successfully.', 'success');
        } catch (error) {
            this.showToast('Error', 'Failed to delete project entries: ' + (error.body?.message || error), 'error');
        }
    }

    handleHoursChange(event) {
        const projectId = event.target.dataset.projectid;
        const date = event.target.dataset.date;
        const value = event.target.value;

        const row = this.matrixRows.find(r => r.projectId === projectId);
        if (row) {
            const dayCell = row.days.find(d => d.date === date);
            if (dayCell) {
                dayCell.hours = value;
            }
        }

        this.recalculateTotals();
    }

    async handleSave() {
        const entriesToSave = [];
        const entriesToDelete = [];

        this.matrixRows.forEach(row => {
            row.days.forEach(day => {
                const hoursNum = parseFloat(day.hours);
                const lookupKey = `${row.projectId}_${day.date}`;
                const existingId = this.existingEntryIds.get(lookupKey);

                if (!isNaN(hoursNum) && hoursNum > 0) {
                    const record = {
                        sobjectType: 'Time_Log_Entry__c',
                        Resource__c: this._recordId,
                        Project__c: row.projectId,
                        Date__c: day.date,
                        Hours__c: hoursNum
                    };

                    if (existingId) {
                        record.Id = existingId;
                    }
                    
                    entriesToSave.push(record);
                } else if (existingId && (isNaN(hoursNum) || hoursNum === 0)) {
                    // Entry existed in DB previously but was cleared or set to 0 -> Delete it
                    entriesToDelete.push(existingId);
                }
            });
        });

        if (entriesToSave.length === 0 && entriesToDelete.length === 0) {
            this.showToast('Info', 'No changes detected to save.', 'info');
            return;
        }

        try {
            await saveTimeEntries({ entriesToSave: entriesToSave, entriesToDelete: entriesToDelete });
            this.showToast('Success', 'Timesheet saved successfully!', 'success');
            
            // Reload directly from DB to refresh IDs and state
            await this.loadExistingTimeEntries();
        } catch (error) {
            this.showToast('Error', 'Failed to save timesheet: ' + (error.body?.message || error), 'error');
        }
    }

    recalculateTotals() {
        let totalSum = 0;
        const colSums = Array(this.monthDays.length).fill(0);

        this.matrixRows.forEach(row => {
            let rowSum = 0;
            row.days.forEach((day, index) => {
                const hrs = parseFloat(day.hours) || 0;
                rowSum += hrs;
                colSums[index] += hrs;
            });
            row.rowTotal = rowSum.toFixed(2);
            totalSum += rowSum;
        });

        this.columnTotals = colSums.map((val, indx) => {
          return {
            val: val > 0 ? val.toFixed(2) : '—',
            key: indx
          }
        });
        this.grandTotal = totalSum.toFixed(2);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get isProjectDisabled() {
        return !this.selectedClientId;
    }
}