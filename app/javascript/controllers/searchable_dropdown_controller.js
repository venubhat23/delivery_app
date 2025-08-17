import { Controller } from "@hotwired/stimulus"

// Reusable Searchable Dropdown Controller
// Connects to data-controller="searchable-dropdown"
export default class extends Controller {
  static targets = ["input", "dropdown", "hiddenField", "loadingIndicator", "resultsList", "noResults"]
  static values = { 
    url: String,
    minQuery: { type: Number, default: 2 },
    placeholder: String,
    required: { type: Boolean, default: false },
    displayFormat: String // "name+email" or "name+phone"
  }

  connect() {
    this.currentRequest = null
    this.searchTimeout = null
    this.setupEventListeners()
    this.setupClickOutside()
  }

  disconnect() {
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    if (this.currentRequest) {
      this.currentRequest.abort()
    }
  }

  setupEventListeners() {
    this.inputTarget.addEventListener('input', this.handleInput.bind(this))
    this.inputTarget.addEventListener('focus', this.handleFocus.bind(this))
    this.inputTarget.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  setupClickOutside() {
    document.addEventListener('click', (event) => {
      if (!this.element.contains(event.target)) {
        this.hideDropdown()
      }
    })
  }

  handleInput(event) {
    const query = event.target.value.trim()
    
    // Clear previous timeout
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }
    
    // Abort previous request
    if (this.currentRequest) {
      this.currentRequest.abort()
    }
    
    // Clear selection if input is empty
    if (query.length === 0) {
      this.clearSelection()
      this.hideDropdown()
      return
    }
    
    // Check minimum query length
    if (query.length < this.minQueryValue) {
      this.hideDropdown()
      return
    }
    
    // Debounce search
    this.searchTimeout = setTimeout(() => {
      this.performSearch(query)
    }, 300)
  }

  handleFocus(event) {
    if (event.target.value.trim().length >= this.minQueryValue) {
      this.performSearch(event.target.value.trim())
    }
  }

  handleKeydown(event) {
    const dropdown = this.dropdownTarget
    if (!dropdown.classList.contains('d-none')) {
      const items = dropdown.querySelectorAll('.search-result-item')
      const activeItem = dropdown.querySelector('.search-result-item.active')
      
      switch (event.key) {
        case 'ArrowDown':
          event.preventDefault()
          this.highlightNext(items, activeItem)
          break
        case 'ArrowUp':
          event.preventDefault()
          this.highlightPrevious(items, activeItem)
          break
        case 'Enter':
          event.preventDefault()
          if (activeItem) {
            activeItem.click()
          }
          break
        case 'Escape':
          this.hideDropdown()
          break
      }
    }
  }

  highlightNext(items, activeItem) {
    let nextIndex = 0
    if (activeItem) {
      activeItem.classList.remove('active')
      const currentIndex = Array.from(items).indexOf(activeItem)
      nextIndex = (currentIndex + 1) % items.length
    }
    if (items[nextIndex]) {
      items[nextIndex].classList.add('active')
    }
  }

  highlightPrevious(items, activeItem) {
    let prevIndex = 0
    if (activeItem) {
      activeItem.classList.remove('active')
      const currentIndex = Array.from(items).indexOf(activeItem)
      prevIndex = currentIndex > 0 ? currentIndex - 1 : items.length - 1
    } else {
      prevIndex = items.length - 1
    }
    if (items[prevIndex]) {
      items[prevIndex].classList.add('active')
    }
  }

  async performSearch(query) {
    this.showLoading()
    
    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set('q', query)
      
      this.currentRequest = fetch(url, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      const response = await this.currentRequest
      const data = await response.json()
      
      this.currentRequest = null
      this.hideLoading()
      
      if (data && data.results && data.results.length > 0) {
        this.displayResults(data.results)
      } else {
        this.showNoResults()
      }
    } catch (error) {
      this.currentRequest = null
      this.hideLoading()
      
      if (error.name !== 'AbortError') {
        console.error('Search error:', error)
        this.showNoResults()
      }
    }
  }

  displayResults(results) {
    this.resultsListTarget.innerHTML = ''
    
    results.forEach((item, index) => {
      const resultElement = this.createResultElement(item)
      this.resultsListTarget.appendChild(resultElement)
    })
    
    this.showDropdown()
  }

  createResultElement(item) {
    const resultItem = document.createElement('div')
    resultItem.className = 'search-result-item p-3 border-bottom cursor-pointer'
    resultItem.style.cursor = 'pointer'
    
    // Add hover effects
    resultItem.addEventListener('mouseenter', () => {
      // Remove active class from other items
      this.resultsListTarget.querySelectorAll('.search-result-item').forEach(el => {
        el.classList.remove('active')
      })
      resultItem.classList.add('active')
    })
    
    resultItem.addEventListener('mouseleave', () => {
      resultItem.classList.remove('active')
    })
    
    // Create content based on display format
    const content = this.createResultContent(item)
    resultItem.innerHTML = content
    
    // Add click handler
    resultItem.addEventListener('click', () => {
      this.selectItem(item)
    })
    
    return resultItem
  }

  createResultContent(item) {
    const avatar = `
      <div class="me-3">
        <div class="avatar-circle">
          ${(item.name || '?').charAt(0).toUpperCase()}
        </div>
      </div>
    `
    
    let details = ''
    if (this.displayFormatValue === 'name+email') {
      details = `
        <div class="fw-bold">${this.escapeHtml(item.name || 'Unknown')}</div>
        <div class="text-muted small">
          ${item.email ? `<i class="fas fa-envelope me-1"></i>${this.escapeHtml(item.email)}` : ''}
          ${item.phone ? `<i class="fas fa-phone me-1 ms-2"></i>${this.escapeHtml(item.phone)}` : ''}
        </div>
        ${item.address ? `<div class="text-muted small"><i class="fas fa-map-marker-alt me-1"></i>${this.escapeHtml(item.address)}</div>` : ''}
      `
    } else if (this.displayFormatValue === 'name+phone') {
      details = `
        <div class="fw-bold">${this.escapeHtml(item.name || 'Unknown')}</div>
        <div class="text-muted small">
          ${item.phone ? `<i class="fas fa-phone me-1"></i>${this.escapeHtml(item.phone)}` : ''}
          ${item.email ? `<i class="fas fa-envelope me-1 ms-2"></i>${this.escapeHtml(item.email)}` : ''}
        </div>
      `
    } else {
      // Default format
      details = `
        <div class="fw-bold">${this.escapeHtml(item.name || 'Unknown')}</div>
        <div class="text-muted small">${this.escapeHtml(item.email || item.phone || '')}</div>
      `
    }
    
    return `
      <div class="d-flex align-items-center">
        ${avatar}
        <div class="flex-grow-1">
          ${details}
        </div>
      </div>
    `
  }

  selectItem(item) {
    // Update the visible input
    this.inputTarget.value = item.name || ''
    
    // Update the hidden field
    this.hiddenFieldTarget.value = item.id || ''
    
    // Hide dropdown
    this.hideDropdown()
    
    // Dispatch custom event for external handling (like auto-populating address)
    this.dispatch('itemSelected', { 
      detail: { 
        item: item,
        controller: this
      } 
    })
    
    // Remove any validation errors
    this.inputTarget.classList.remove('is-invalid')
    
    // Mark input as valid if it was required
    if (this.requiredValue) {
      this.inputTarget.setCustomValidity('')
    }
  }

  clearSelection() {
    this.hiddenFieldTarget.value = ''
    
    if (this.requiredValue && this.inputTarget.value.trim() === '') {
      this.inputTarget.setCustomValidity('This field is required')
    }
  }

  showLoading() {
    this.loadingIndicatorTarget.classList.remove('d-none')
    this.resultsListTarget.classList.add('d-none')
    this.noResultsTarget.classList.add('d-none')
    this.dropdownTarget.classList.remove('d-none')
  }

  hideLoading() {
    this.loadingIndicatorTarget.classList.add('d-none')
  }

  showDropdown() {
    this.dropdownTarget.classList.remove('d-none')
    this.resultsListTarget.classList.remove('d-none')
    this.noResultsTarget.classList.add('d-none')
  }

  hideDropdown() {
    this.dropdownTarget.classList.add('d-none')
    
    // Clear any active highlights
    this.resultsListTarget.querySelectorAll('.search-result-item').forEach(el => {
      el.classList.remove('active')
    })
  }

  showNoResults() {
    this.resultsListTarget.classList.add('d-none')
    this.noResultsTarget.classList.remove('d-none')
    this.dropdownTarget.classList.remove('d-none')
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // Public method to reset the dropdown
  reset() {
    this.inputTarget.value = ''
    this.hiddenFieldTarget.value = ''
    this.hideDropdown()
    this.inputTarget.classList.remove('is-invalid')
  }

  // Public method to set value programmatically
  setValue(item) {
    this.selectItem(item)
  }
}