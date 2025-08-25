// Global date formatting helpers for DD/MM/YYYY format

window.DateHelpers = {
  // Format date to DD/MM/YYYY string
  formatDate: function(date) {
    if (!date) return '';
    
    if (typeof date === 'string') {
      date = new Date(date);
    }
    
    if (!(date instanceof Date) || isNaN(date.getTime())) {
      return '';
    }
    
    var day = date.getDate().toString().padStart(2, '0');
    var month = (date.getMonth() + 1).toString().padStart(2, '0');
    var year = date.getFullYear();
    
    return day + '/' + month + '/' + year;
  },
  
  // Parse DD/MM/YYYY string to Date object
  parseDate: function(dateString) {
    if (!dateString) return null;
    
    var parts = dateString.split('/');
    if (parts.length !== 3) return null;
    
    var day = parseInt(parts[0], 10);
    var month = parseInt(parts[1], 10) - 1; // Month is 0-indexed
    var year = parseInt(parts[2], 10);
    
    return new Date(year, month, day);
  },
  
  // Convert DD/MM/YYYY to YYYY-MM-DD for input[type="date"]
  toInputFormat: function(dateString) {
    if (!dateString) return '';
    
    var parts = dateString.split('/');
    if (parts.length !== 3) return '';
    
    var day = parts[0].padStart(2, '0');
    var month = parts[1].padStart(2, '0');
    var year = parts[2];
    
    return year + '-' + month + '-' + day;
  },
  
  // Convert YYYY-MM-DD from input[type="date"] to DD/MM/YYYY
  fromInputFormat: function(inputDate) {
    if (!inputDate) return '';
    
    var date = new Date(inputDate);
    return this.formatDate(date);
  },
  
  // Format date with time in DD/MM/YYYY HH:MM format
  formatDateTime: function(date) {
    if (!date) return '';
    
    if (typeof date === 'string') {
      date = new Date(date);
    }
    
    if (!(date instanceof Date) || isNaN(date.getTime())) {
      return '';
    }
    
    var dateStr = this.formatDate(date);
    var hours = date.getHours().toString().padStart(2, '0');
    var minutes = date.getMinutes().toString().padStart(2, '0');
    
    return dateStr + ' ' + hours + ':' + minutes;
  },
  
  // Get today's date in DD/MM/YYYY format
  today: function() {
    return this.formatDate(new Date());
  }
};

// Legacy support - maintain existing function names
window.formatDate = window.DateHelpers.formatDate;
window.parseDate = window.DateHelpers.parseDate;