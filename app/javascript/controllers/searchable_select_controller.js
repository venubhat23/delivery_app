import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]
  static values = { 
    url: String,
    placeholder: String,
    allowClear: Boolean,
    minimumInputLength: Number
  }

  connect() {
    this.initializeSelect2()
  }

  disconnect() {
    if (this.select2Instance) {
      this.select2Instance.destroy()
    }
  }

  initializeSelect2() {
    const options = {
      theme: "bootstrap-5",
      placeholder: this.placeholderValue || "Select an option...",
      allowClear: this.allowClearValue !== false,
      width: "100%",
      dropdownParent: $(this.element.closest('.modal') || 'body')
    }

    // If URL is provided, enable AJAX search
    if (this.urlValue) {
      options.ajax = {
        url: this.urlValue,
        dataType: 'json',
        delay: 250,
        data: (params) => {
          return {
            q: params.term,
            page: params.page || 1
          }
        },
        processResults: (data) => {
          return {
            results: data.results || data,
            pagination: {
              more: data.pagination ? data.pagination.more : false
            }
          }
        },
        cache: true
      }
      options.minimumInputLength = this.minimumInputLengthValue || 1
    }

    this.select2Instance = $(this.selectTarget).select2(options)

    // Handle Turbo navigation
    this.select2Instance.on('select2:select', (e) => {
      // Trigger change event for Rails form handling
      this.selectTarget.dispatchEvent(new Event('change', { bubbles: true }))
    })
  }

  // Method to refresh options via AJAX
  refresh() {
    if (this.select2Instance) {
      this.select2Instance.trigger('change')
    }
  }

  // Method to clear selection
  clear() {
    if (this.select2Instance) {
      this.select2Instance.val(null).trigger('change')
    }
  }

  // Method to set value programmatically
  setValue(value) {
    if (this.select2Instance) {
      this.select2Instance.val(value).trigger('change')
    }
  }
}