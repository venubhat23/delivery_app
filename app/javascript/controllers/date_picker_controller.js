import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    mode: String,
    minDate: String,
    maxDate: String,
    enableTime: Boolean,
    dateFormat: String,
    altFormat: String,
    defaultDate: String,
    disable: Array,
    enable: Array,
    inline: Boolean,
    allowInput: Boolean,
    clickOpens: Boolean
  }

  connect() {
    this.initializeDatePicker()
  }

  disconnect() {
    if (this.flatpickrInstance) {
      this.flatpickrInstance.destroy()
    }
  }

  initializeDatePicker() {
    const options = {
      mode: this.modeValue || "single", // single, multiple, range
      dateFormat: this.dateFormatValue || "Y-m-d",
      altInput: true,
      altFormat: this.altFormatValue || "F j, Y",
      allowInput: this.allowInputValue !== false,
      clickOpens: this.clickOpensValue !== false,
      theme: "material_blue"
    }

    // Set min/max dates
    if (this.minDateValue) {
      options.minDate = this.minDateValue
    }
    if (this.maxDateValue) {
      options.maxDate = this.maxDateValue
    }

    // Enable time picker
    if (this.enableTimeValue) {
      options.enableTime = true
      options.dateFormat = "Y-m-d H:i"
      options.altFormat = "F j, Y at h:i K"
    }

    // Set default date
    if (this.defaultDateValue) {
      options.defaultDate = this.defaultDateValue
    }

    // Disable specific dates
    if (this.disableValue && this.disableValue.length > 0) {
      options.disable = this.disableValue
    }

    // Enable only specific dates
    if (this.enableValue && this.enableValue.length > 0) {
      options.enable = this.enableValue
    }

    // Inline mode
    if (this.inlineValue) {
      options.inline = true
    }

    // Add custom styling and behavior
    options.onReady = (selectedDates, dateStr, instance) => {
      this.addCustomStyling(instance)
    }

    options.onChange = (selectedDates, dateStr, instance) => {
      this.handleDateChange(selectedDates, dateStr, instance)
    }

    this.flatpickrInstance = flatpickr(this.inputTarget, options)
  }

  addCustomStyling(instance) {
    // Add custom classes for better integration with Bootstrap
    const calendar = instance.calendarContainer
    calendar.classList.add('shadow-lg', 'border-0')
  }

  handleDateChange(selectedDates, dateStr, instance) {
    // Dispatch custom event for other controllers to listen to
    this.dispatch('dateChanged', {
      detail: {
        selectedDates: selectedDates,
        dateStr: dateStr,
        instance: instance
      }
    })

    // Trigger change event for Rails form handling
    this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
  }

  // Method to set date programmatically
  setDate(date) {
    if (this.flatpickrInstance) {
      this.flatpickrInstance.setDate(date)
    }
  }

  // Method to clear date
  clear() {
    if (this.flatpickrInstance) {
      this.flatpickrInstance.clear()
    }
  }

  // Method to get selected dates
  getSelectedDates() {
    if (this.flatpickrInstance) {
      return this.flatpickrInstance.selectedDates
    }
    return []
  }

  // Method to refresh the calendar
  refresh() {
    if (this.flatpickrInstance) {
      this.flatpickrInstance.redraw()
    }
  }
}