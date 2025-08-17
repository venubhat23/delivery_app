import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "startDate", "endDate", "frequency", "schedulePreview", 
    "scheduleInfo", "deliveryType", "singleDateField", 
    "scheduledDateFields", "submitButton"
  ]
  static values = {
    deliveryType: String
  }

  connect() {
    this.updateDeliveryTypeDisplay()
    this.updateSchedulePreview()
  }

  // Handle delivery type change (single vs scheduled)
  deliveryTypeChanged(event) {
    this.deliveryTypeValue = event.target.value
    this.updateDeliveryTypeDisplay()
    this.updateSchedulePreview()
  }

  updateDeliveryTypeDisplay() {
    const isSingle = this.deliveryTypeValue === 'single'
    
    // Show/hide appropriate fields
    if (this.hasSingleDateFieldTarget) {
      this.singleDateFieldTarget.style.display = isSingle ? 'block' : 'none'
    }
    
    if (this.hasScheduledDateFieldsTarget) {
      this.scheduledDateFieldsTarget.style.display = isSingle ? 'none' : 'block'
    }

    // Update submit button text
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.textContent = isSingle ? 
        'Create Single Delivery' : 'Create Delivery Schedule'
    }
  }

  // Handle date changes
  dateChanged() {
    this.updateSchedulePreview()
    this.validateDateRange()
  }

  frequencyChanged() {
    this.updateSchedulePreview()
  }

  updateSchedulePreview() {
    if (this.deliveryTypeValue === 'single') {
      this.updateSingleDeliveryPreview()
    } else {
      this.updateScheduledDeliveryPreview()
    }
  }

  updateSingleDeliveryPreview() {
    if (this.hasScheduleInfoTarget) {
      this.scheduleInfoTarget.innerHTML = `
        <div class="d-flex align-items-center">
          <i class="fas fa-truck text-primary me-2"></i>
          <span>Single delivery assignment will be created</span>
        </div>
      `
    }
  }

  updateScheduledDeliveryPreview() {
    if (!this.hasStartDateTarget || !this.hasEndDateTarget || !this.hasFrequencyTarget) {
      return
    }

    const startDate = this.startDateTarget.value
    const endDate = this.endDateTarget.value
    const frequency = this.frequencyTarget.value

    if (startDate && endDate && frequency) {
      const start = new Date(startDate)
      const end = new Date(endDate)

      if (start <= end) {
        const deliveryCount = this.calculateDeliveryCount(start, end, frequency)
        const nextDeliveries = this.getNextDeliveryDates(start, frequency, 3)
        
        this.scheduleInfoTarget.innerHTML = `
          <div class="mb-3">
            <div class="d-flex align-items-center mb-2">
              <i class="fas fa-calendar-alt text-success me-2"></i>
              <strong>${deliveryCount}</strong> delivery assignments will be created
            </div>
            <small class="text-muted">
              From ${this.formatDate(start)} to ${this.formatDate(end)}
            </small>
          </div>
          <div class="mb-2">
            <strong>Next deliveries:</strong>
          </div>
          <ul class="list-unstyled small">
            ${nextDeliveries.map(date => `
              <li class="mb-1">
                <i class="fas fa-circle text-primary me-2" style="font-size: 0.5rem;"></i>
                ${this.formatDate(date)}
              </li>
            `).join('')}
            ${deliveryCount > 3 ? '<li class="text-muted">... and more</li>' : ''}
          </ul>
        `
      } else {
        this.scheduleInfoTarget.innerHTML = `
          <div class="alert alert-warning mb-0">
            <i class="fas fa-exclamation-triangle me-2"></i>
            End date must be after start date
          </div>
        `
      }
    } else {
      this.scheduleInfoTarget.innerHTML = `
        <div class="text-muted">
          <i class="fas fa-info-circle me-2"></i>
          Select dates and frequency to see preview
        </div>
      `
    }
  }

  calculateDeliveryCount(start, end, frequency) {
    let deliveryCount = 0
    let current = new Date(start)

    while (current <= end) {
      deliveryCount++
      current = this.getNextDate(current, frequency)
    }

    return deliveryCount
  }

  getNextDeliveryDates(start, frequency, count) {
    const dates = []
    let current = new Date(start)

    for (let i = 0; i < count; i++) {
      dates.push(new Date(current))
      current = this.getNextDate(current, frequency)
    }

    return dates
  }

  getNextDate(current, frequency) {
    const next = new Date(current)
    
    switch (frequency) {
      case 'daily':
        next.setDate(next.getDate() + 1)
        break
      case 'weekly':
        next.setDate(next.getDate() + 7)
        break
      case 'bi_weekly':
        next.setDate(next.getDate() + 14)
        break
      case 'monthly':
        next.setMonth(next.getMonth() + 1)
        break
      default:
        next.setDate(next.getDate() + 1)
    }

    return next
  }

  validateDateRange() {
    if (!this.hasStartDateTarget || !this.hasEndDateTarget) return

    const startDate = this.startDateTarget.value
    const endDate = this.endDateTarget.value

    if (startDate && endDate) {
      const start = new Date(startDate)
      const end = new Date(endDate)
      const today = new Date()
      today.setHours(0, 0, 0, 0)

      // Check if end date is before start date
      if (end < start) {
        this.showValidationError('End date must be after start date')
        return false
      }

      this.clearValidationError()
      return true
    }

    return true
  }

  showValidationError(message) {
    // Remove existing error
    this.clearValidationError()

    // Add error message
    const errorDiv = document.createElement('div')
    errorDiv.className = 'alert alert-danger mt-2'
    errorDiv.id = 'date-validation-error'
    errorDiv.innerHTML = `<i class="fas fa-exclamation-triangle me-2"></i>${message}`

    if (this.hasEndDateTarget) {
      this.endDateTarget.parentNode.appendChild(errorDiv)
    }
  }

  clearValidationError() {
    const existingError = document.getElementById('date-validation-error')
    if (existingError) {
      existingError.remove()
    }
  }

  formatDate(date) {
    return date.toLocaleDateString('en-US', {
      weekday: 'short',
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    })
  }

  // Handle customer selection and update preview
  customerSelected(event) {
    const customer = event.detail.item
    
    // Update the schedule preview to show customer info
    this.updateCustomerPreview(customer)
    
    // Dispatch custom event for other controllers that might need to know
    this.dispatch('customerChanged', { 
      detail: { 
        customer: customer,
        customerId: customer.id
      } 
    })
  }

  updateCustomerPreview(customer) {
    // Find or create customer preview section
    let customerPreview = this.element.querySelector('.customer-preview')
    if (!customerPreview && this.hasSchedulePreviewTarget) {
      customerPreview = document.createElement('div')
      customerPreview.className = 'customer-preview mb-3 p-3 bg-light rounded'
      this.schedulePreviewTarget.prepend(customerPreview)
    }

    if (customerPreview) {
      customerPreview.innerHTML = `
        <div class="d-flex align-items-center">
          <div class="me-3">
            <div class="avatar-circle-sm">
              ${customer.name.charAt(0).toUpperCase()}
            </div>
          </div>
          <div>
            <div class="fw-bold text-primary">${customer.name}</div>
            <div class="text-muted small">
              ${customer.phone ? `<i class="fas fa-phone me-1"></i>${customer.phone}` : ''}
              ${customer.email ? `<i class="fas fa-envelope me-1 ms-2"></i>${customer.email}` : ''}
            </div>
            ${customer.address ? `<div class="text-muted small"><i class="fas fa-map-marker-alt me-1"></i>${customer.address}</div>` : ''}
          </div>
        </div>
      `
    }
  }

  // Handle form submission
  submitForm(event) {
    if (this.deliveryTypeValue === 'scheduled') {
      if (!this.validateDateRange()) {
        event.preventDefault()
        return false
      }
    }

    return true
  }
}