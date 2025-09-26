import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hiddenField", "dropdown", "list"]
  static values = {
    url: String,
    selectedId: String,
    selectedName: String
  }

  connect() {
    this.debounceTimer = null
    this.isOpen = false
    this.selectedIndex = -1

    // Set initial values if provided
    if (this.selectedIdValue && this.selectedNameValue) {
      this.inputTarget.value = this.selectedNameValue
      this.hiddenFieldTarget.value = this.selectedIdValue
    }

    // Load all customers initially
    this.loadAllCustomers()
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  async loadAllCustomers() {
    try {
      const response = await fetch(`${this.urlValue}?q=&load_all=true`)
      const data = await response.json()
      this.allCustomers = data.results || []
      this.showDropdown(this.allCustomers)
    } catch (error) {
      console.error('Error loading customers:', error)
    }
  }

  onInputFocus(event) {
    if (!this.isOpen) {
      if (this.inputTarget.value.trim() === '') {
        this.showDropdown(this.allCustomers)
      } else {
        this.search()
      }
    }
  }

  onInputBlur(event) {
    // Delay hiding to allow clicking on dropdown items
    setTimeout(() => {
      this.hideDropdown()
    }, 150)
  }

  onInput(event) {
    const query = event.target.value.trim()

    // Clear the hidden field when input changes
    if (this.hiddenFieldTarget.value &&
        query !== this.inputTarget.dataset.selectedName) {
      this.hiddenFieldTarget.value = ''
      this.inputTarget.dataset.selectedName = ''
    }

    // Clear existing timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // If empty, show all customers
    if (query === '') {
      this.showDropdown(this.allCustomers)
      return
    }

    // Debounce search
    this.debounceTimer = setTimeout(() => {
      this.search(query)
    }, 200)
  }

  async search(query = null) {
    if (query === null) {
      query = this.inputTarget.value.trim()
    }

    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
      const data = await response.json()
      const customers = data.results || []
      this.showDropdown(customers)
    } catch (error) {
      console.error('Error searching customers:', error)
      this.hideDropdown()
    }
  }

  showDropdown(customers) {
    this.selectedIndex = -1
    this.listTarget.innerHTML = ''

    if (customers.length === 0) {
      this.listTarget.innerHTML = '<li class="dropdown-item text-muted">No customers found</li>'
    } else {
      customers.forEach((customer, index) => {
        const li = document.createElement('li')
        li.innerHTML = `
          <a class="dropdown-item customer-option"
             href="#"
             data-id="${customer.id}"
             data-name="${customer.text}"
             data-index="${index}">
            ${this.highlightMatch(customer.text, this.inputTarget.value)}
          </a>
        `
        li.addEventListener('click', (e) => this.selectCustomer(e))
        this.listTarget.appendChild(li)
      })
    }

    this.dropdownTarget.classList.add('show')
    this.isOpen = true
  }

  hideDropdown() {
    this.dropdownTarget.classList.remove('show')
    this.isOpen = false
    this.selectedIndex = -1
  }

  highlightMatch(text, query) {
    if (!query || query.length === 0) return text

    const regex = new RegExp(`(${this.escapeRegex(query)})`, 'gi')
    return text.replace(regex, '<mark class="bg-warning">$1</mark>')
  }

  escapeRegex(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  }

  selectCustomer(event) {
    event.preventDefault()

    const link = event.target.closest('.customer-option')
    const customerId = link.dataset.id
    const customerName = link.dataset.name

    this.inputTarget.value = customerName
    this.hiddenFieldTarget.value = customerId
    this.inputTarget.dataset.selectedName = customerName

    this.hideDropdown()

    // Trigger form submission
    this.hiddenFieldTarget.dispatchEvent(new Event('change', { bubbles: true }))
  }

  onKeydown(event) {
    if (!this.isOpen) return

    const items = this.listTarget.querySelectorAll('.customer-option')

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
        this.updateSelection(items)
        break

      case 'ArrowUp':
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, -1)
        this.updateSelection(items)
        break

      case 'Enter':
        event.preventDefault()
        if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
          items[this.selectedIndex].click()
        }
        break

      case 'Escape':
        event.preventDefault()
        this.hideDropdown()
        break
    }
  }

  updateSelection(items) {
    items.forEach((item, index) => {
      item.classList.toggle('active', index === this.selectedIndex)
    })

    // Scroll selected item into view
    if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
      items[this.selectedIndex].scrollIntoView({ block: 'nearest' })
    }
  }

  clear() {
    this.inputTarget.value = ''
    this.hiddenFieldTarget.value = ''
    this.inputTarget.dataset.selectedName = ''
    this.showDropdown(this.allCustomers)
  }
}