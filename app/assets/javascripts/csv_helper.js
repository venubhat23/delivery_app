// app/assets/javascripts/csv_helper.js or include in your layout

document.addEventListener('DOMContentLoaded', function() {
  const csvTextarea = document.getElementById('csv_data');
  
  if (csvTextarea) {
    // Handle paste event
    csvTextarea.addEventListener('paste', function(e) {
      setTimeout(function() {
        const pastedData = csvTextarea.value;
        if (pastedData) {
          // Auto-format the data
          const lines = pastedData.split('\n');
          const formattedData = lines.map(line => line.trim()).filter(line => line).join('\n');
          csvTextarea.value = formattedData;
          
          // Auto-validate after paste
          if (typeof validateCSV === 'function') {
            validateCSV();
          }
        }
      }, 100);
    });
    
    // Handle drag and drop
    csvTextarea.addEventListener('dragover', function(e) {
      e.preventDefault();
      csvTextarea.classList.add('drag-over');
    });
    
    csvTextarea.addEventListener('dragleave', function(e) {
      csvTextarea.classList.remove('drag-over');
    });
    
    csvTextarea.addEventListener('drop', function(e) {
      e.preventDefault();
      csvTextarea.classList.remove('drag-over');
      
      const files = e.dataTransfer.files;
      if (files.length > 0) {
        const file = files[0];
        if (file.type === 'text/csv' || file.name.endsWith('.csv')) {
          const reader = new FileReader();
          reader.onload = function(e) {
            csvTextarea.value = e.target.result;
            if (typeof validateCSV === 'function') {
              validateCSV();
            }
          };
          reader.readAsText(file);
        } else {
          alert('Please drop a CSV file');
        }
      }
    });
  }
});

// Helper function to format CSV data
function formatCSVData(data) {
  const lines = data.split('\n');
  return lines.map(line => line.trim()).filter(line => line).join('\n');
}

// Helper function to count CSV rows
function countCSVRows(data) {
  const lines = data.split('\n').filter(line => line.trim());
  return Math.max(0, lines.length - 1); // Subtract 1 for header
}