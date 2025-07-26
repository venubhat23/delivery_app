// Sales Customer Modal Handling
document.addEventListener('DOMContentLoaded', function() {
  // Handle Sales Customer Form Submission
  const salesCustomerForm = document.getElementById('salesCustomerForm');
  if (salesCustomerForm) {
    salesCustomerForm.addEventListener('submit', function(e) {
      e.preventDefault();
      
      const formData = new FormData(this);
      
      fetch('/sales_customers', {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          // Add new customer to dropdown
          const customerSelect = document.getElementById('customer_select');
          const salesCustomersOptgroup = customerSelect.querySelector('optgroup[label="Sales Customers"]');
          
          const newOption = document.createElement('option');
          newOption.value = data.customer.id;
          newOption.setAttribute('data-type', 'SalesCustomer');
          newOption.setAttribute('data-name', data.customer.name);
          newOption.setAttribute('data-address', data.customer.address);
          newOption.setAttribute('data-phone', data.customer.phone);
          newOption.setAttribute('data-email', data.customer.email);
          newOption.setAttribute('data-gst', data.customer.gst_number);
          newOption.textContent = `${data.customer.name} - ${data.customer.phone}`;
          newOption.selected = true;
          
          salesCustomersOptgroup.appendChild(newOption);
          
          // Update hidden fields
          document.getElementById('hidden_sales_customer_id').value = data.customer.id;
          document.getElementById('hidden_customer_id').value = '';
          
          // Update customer details
          document.querySelector('input[name="sales_invoice[customer_name]"]').value = data.customer.name;
          document.querySelector('textarea[name="sales_invoice[bill_to]"]').value = data.customer.address;
          document.querySelector('textarea[name="sales_invoice[ship_to]"]').value = data.customer.address;
          
          // Close modal
          const modal = bootstrap.Modal.getInstance(document.getElementById('createSalesCustomerModal'));
          modal.hide();
          
          // Reset form
          salesCustomerForm.reset();
          
          // Show success message
          showAlert('success', data.message);
        } else {
          showAlert('danger', 'Error: ' + data.errors.join(', '));
        }
      })
      .catch(error => {
        console.error('Error:', error);
        showAlert('danger', 'An error occurred while creating the customer.');
      });
    });
  }
  
  // Handle Sales Product Form Submission
  const salesProductForm = document.getElementById('salesProductForm');
  if (salesProductForm) {
    salesProductForm.addEventListener('submit', function(e) {
      e.preventDefault();
      
      const formData = new FormData(this);
      
      fetch('/sales_products', {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          // Add new product to all product dropdowns
          const productSelects = document.querySelectorAll('.sales-product-select');
          
          productSelects.forEach(select => {
            const newOption = document.createElement('option');
            newOption.value = data.product.id;
            newOption.setAttribute('data-type', 'SalesProduct');
            newOption.setAttribute('data-price', data.product.sales_price);
            newOption.setAttribute('data-tax', data.product.tax_rate || 0);
            newOption.setAttribute('data-hsn', data.product.hsn_sac || '');
            newOption.setAttribute('data-stock', data.product.current_stock);
            newOption.textContent = `${data.product.name} (${data.product.measuring_unit}) (Stock: ${data.product.current_stock})`;
            
            select.appendChild(newOption);
          });
          
          // Close modal
          const modal = bootstrap.Modal.getInstance(document.getElementById('createSalesProductModal'));
          modal.hide();
          
          // Reset form
          salesProductForm.reset();
          
          // Show success message
          showAlert('success', data.message);
        } else {
          showAlert('danger', 'Error: ' + data.errors.join(', '));
        }
      })
      .catch(error => {
        console.error('Error:', error);
        showAlert('danger', 'An error occurred while creating the product.');
      });
    });
  }
});

// Function to show alert messages
function showAlert(type, message) {
  const alertDiv = document.createElement('div');
  alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
  alertDiv.innerHTML = `
    ${message}
    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
  `;
  
  // Insert at the top of the container
  const container = document.querySelector('.container-fluid');
  container.insertBefore(alertDiv, container.firstChild);
  
  // Auto-hide after 5 seconds
  setTimeout(() => {
    if (alertDiv.parentNode) {
      alertDiv.remove();
    }
  }, 5000);
}

// Function to open add product modal (called from button)
function openAddProductModal(button) {
  const modal = new bootstrap.Modal(document.getElementById('createSalesProductModal'));
  modal.show();
}