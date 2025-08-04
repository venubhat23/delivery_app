import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]
  static values = { 
    url: String,
    placeholder: String,
    allowClear: Boolean,
    minimumInputLength: Number,
    searchType: String, // 'ajax' or 'local'
    searchFields: Array // fields to search in for local search
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
      placeholder: this.placeholderValue || "Search and select...",
      allowClear: this.allowClearValue !== false,
      width: "100%",
      dropdownParent: $(this.element.closest('.modal') || 'body'),
      escapeMarkup: function(markup) { return markup; }, // Allow HTML in options
      templateResult: this.formatResult.bind(this),
      templateSelection: this.formatSelection.bind(this)
    }

    // Enhanced search functionality
    if (this.searchTypeValue === 'ajax' && this.urlValue) {
      // AJAX search for large datasets
      options.ajax = {
        url: this.urlValue,
        dataType: 'json',
        delay: 250,
        data: (params) => {
          return {
            q: params.term,
            page: params.page || 1,
            per_page: 20
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
    } else {
      // Local search for smaller datasets - enhanced matching
      options.matcher = this.customMatcher.bind(this)
      options.minimumInputLength = 0
    }

    this.select2Instance = $(this.selectTarget).select2(options)

    // Handle Turbo navigation and form events
    this.select2Instance.on('select2:select', (e) => {
      this.selectTarget.dispatchEvent(new Event('change', { bubbles: true }))
    })

    this.select2Instance.on('select2:unselect', (e) => {
      this.selectTarget.dispatchEvent(new Event('change', { bubbles: true }))
    })
  }

  // Enhanced custom matcher for local search
  customMatcher(params, data) {
    // If there are no search terms, return all data
    if ($.trim(params.term) === '') {
      return data;
    }

    // Skip if there is no 'text' property
    if (typeof data.text === 'undefined') {
      return null;
    }

    const searchTerm = params.term.toLowerCase();
    const text = data.text.toLowerCase();
    
    // Enhanced matching logic
    // 1. Exact match
    if (text === searchTerm) {
      return data;
    }
    
    // 2. Starts with match (higher priority)
    if (text.indexOf(searchTerm) === 0) {
      return data;
    }
    
    // 3. Contains match
    if (text.indexOf(searchTerm) > -1) {
      return data;
    }
    
    // 4. Word boundary match (matches whole words)
    const words = text.split(/\s+/);
    for (let word of words) {
      if (word.indexOf(searchTerm) === 0) {
        return data;
      }
    }
    
    // 5. Fuzzy match for typos (simple implementation)
    if (this.fuzzyMatch(searchTerm, text)) {
      return data;
    }

    return null;
  }

  // Simple fuzzy matching for typos
  fuzzyMatch(search, text) {
    if (search.length < 3) return false; // Only for longer searches
    
    let searchIndex = 0;
    for (let i = 0; i < text.length && searchIndex < search.length; i++) {
      if (text[i] === search[searchIndex]) {
        searchIndex++;
      }
    }
    
    // Allow for 1-2 character differences
    const threshold = search.length > 5 ? 2 : 1;
    return (search.length - searchIndex) <= threshold;
  }

  // Format search results with highlighting
  formatResult(data) {
    if (data.loading) {
      return data.text;
    }

    // If there's a search term, highlight it
    const term = $('.select2-search__field').val();
    if (term && term.length > 0) {
      const regex = new RegExp('(' + this.escapeRegex(term) + ')', 'gi');
      const highlighted = data.text.replace(regex, '<mark>$1</mark>');
      return $('<span>' + highlighted + '</span>');
    }

    return data.text;
  }

  // Format selected option
  formatSelection(data) {
    return data.text;
  }

  // Escape special regex characters
  escapeRegex(term) {
    return term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
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

  // Method to add new option dynamically
  addOption(id, text, selected = false) {
    if (this.select2Instance) {
      const option = new Option(text, id, selected, selected);
      $(this.selectTarget).append(option);
      if (selected) {
        this.select2Instance.trigger('change');
      }
    }
  }

  // Method to update placeholder
  updatePlaceholder(newPlaceholder) {
    if (this.select2Instance) {
      this.select2Instance.destroy();
      this.placeholderValue = newPlaceholder;
      this.initializeSelect2();
    }
  }
}