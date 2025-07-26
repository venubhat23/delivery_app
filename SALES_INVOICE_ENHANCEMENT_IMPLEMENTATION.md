# Sales Invoice Enhancement Implementation

## Overview

This implementation enhances the `sales_invoices/new` page with the following features:

### Customer Section Enhancements:
1. **SalesCustomer Model**: Created a separate `SalesCustomer` entity for sales-specific customers
2. **Unified Customer Dropdown**: Loads both `Customer` and `SalesCustomer` records in the same dropdown with clear grouping
3. **Create Customer Modal**: Added modal functionality to create new `SalesCustomer` records with comprehensive fields

### Product/Item Section Enhancements:
1. **Dual Product Support**: Support for both existing `Product` and `SalesProduct` entities
2. **Item Type Selection**: Dropdown to choose between "Product" and "SalesProduct"
3. **Dynamic Product Selection**: Product dropdown changes based on selected item type
4. **Create Product Modal**: Modal to create new `SalesProduct` records for ad-hoc sales items

## Files Created/Modified

### New Models
- `app/models/sales_customer.rb` - New model for sales-specific customers
- Enhanced `app/models/sales_invoice.rb` - Added support for both customer types
- Enhanced `app/models/sales_invoice_item.rb` - Added support for both product types

### New Controllers
- `app/controllers/sales_customers_controller.rb` - CRUD operations for SalesCustomer

### New Views
- `app/views/sales_customers/_modal_form.html.erb` - Modal form for creating SalesCustomers
- `app/views/sales_products/_modal_form.html.erb` - Modal form for creating SalesProducts

### Enhanced Views
- `app/views/sales_invoices/new.html.erb` - Updated with dual customer/product support

### New JavaScript
- `app/assets/javascripts/sales_invoices.js` - Modal handling and AJAX functionality

### Database Migrations
- `db/migrate/20250130120001_create_sales_customers.rb` - Creates sales_customers table
- `db/migrate/20250130120002_add_sales_customer_to_sales_invoices.rb` - Adds sales_customer_id to sales_invoices
- `db/migrate/20250130120003_add_item_type_to_sales_invoice_items.rb` - Adds item_type and product_id to sales_invoice_items

### Routes
- Added `resources :sales_customers` with search functionality

## Database Schema Changes

### SalesCustomers Table
```ruby
create_table :sales_customers do |t|
  t.string :name, null: false
  t.text :address
  t.string :city
  t.string :state
  t.string :pincode
  t.string :phone_number, null: false
  t.string :email
  t.string :gst_number
  t.string :pan_number
  t.string :contact_person
  t.text :shipping_address
  t.boolean :is_active, default: true
  t.timestamps
end
```

### SalesInvoices Table Updates
- Added `sales_customer_id` foreign key (optional)
- Maintains backward compatibility with existing `customer_id`

### SalesInvoiceItems Table Updates
- Added `item_type` column (default: 'SalesProduct')
- Added `product_id` foreign key (optional)
- Maintains backward compatibility with existing `sales_product_id`

## Key Features

### Customer Management
1. **Unified Selection**: Single dropdown showing both Customer and SalesCustomer records
2. **Type Identification**: Clear grouping with "Regular Customers" and "Sales Customers" optgroups
3. **Modal Creation**: Click "+" button to open modal for creating new SalesCustomer
4. **Auto-population**: Customer details auto-populate when selected
5. **Validation**: Comprehensive validation for required fields

### Product Management
1. **Type Selection**: Dropdown to choose between "Product" and "SalesProduct"
2. **Dynamic UI**: Product selection dropdown changes based on item type
3. **Stock Display**: Shows current stock for both product types
4. **Modal Creation**: Click "+" button to create new SalesProduct
5. **Price Auto-fill**: Product selection auto-fills price, tax rate, and HSN/SAC

### Form Behavior
1. **Backward Compatibility**: Existing functionality remains unchanged
2. **Progressive Enhancement**: New features enhance without breaking existing flows
3. **AJAX Integration**: Modal forms submit via AJAX without page reload
4. **Real-time Updates**: New records immediately appear in dropdowns

## Technical Implementation Details

### Customer Selection Logic
```javascript
// Handles both Customer and SalesCustomer selection
document.getElementById('customer_select').addEventListener('change', function() {
  const selectedOption = this.options[this.selectedIndex];
  const customerType = selectedOption.getAttribute('data-type');
  
  if (customerType === 'SalesCustomer') {
    document.getElementById('hidden_sales_customer_id').value = selectedOption.value;
    document.getElementById('hidden_customer_id').value = '';
  } else if (customerType === 'Customer') {
    document.getElementById('hidden_customer_id').value = selectedOption.value;
    document.getElementById('hidden_sales_customer_id').value = '';
  }
});
```

### Product Type Toggle
```javascript
function toggleProductOptions(selectElement) {
  const row = selectElement.closest('tr');
  const salesProductSelect = row.querySelector('.sales-product-select');
  const regularProductSelect = row.querySelector('.regular-product-select');
  
  if (selectElement.value === 'Product') {
    salesProductSelect.style.display = 'none';
    regularProductSelect.style.display = 'block';
  } else {
    salesProductSelect.style.display = 'block';
    regularProductSelect.style.display = 'none';
  }
}
```

### Model Relationships
```ruby
# SalesInvoice model supports both customer types
belongs_to :customer, optional: true
belongs_to :sales_customer, optional: true

def get_customer
  sales_customer || customer
end

# SalesInvoiceItem model supports both product types
belongs_to :sales_product, optional: true
belongs_to :product, optional: true

def get_product
  item_type == 'Product' ? product : sales_product
end
```

## Usage Instructions

### Creating a Sales Invoice with SalesCustomer
1. Navigate to Sales Invoices → New
2. In Customer dropdown, select from "Sales Customers" group OR
3. Click "+" button to create new SalesCustomer
4. Fill modal form with customer details
5. Customer automatically populates in invoice

### Adding Products to Invoice
1. For each line item, choose "Item/Service Type":
   - "Sales Product" for inventory-managed products
   - "Regular Product" for basic products
2. Select product from appropriate dropdown OR
3. Click "+" to create new SalesProduct
4. Product details auto-populate

### Modal Forms
- **SalesCustomer Modal**: Comprehensive form with name, contact, address, GST details
- **SalesProduct Modal**: Product form with pricing, stock, tax information
- Both modals submit via AJAX and update dropdowns immediately

## Validation & Error Handling

### SalesCustomer Validation
- Name: Required, unique
- Phone: Required
- Email: Valid format (optional)
- GST: Valid GST format (optional)

### SalesInvoiceItem Validation
- Item type validation ensures proper product association
- Quantity and price validation
- Stock availability checking

### JavaScript Error Handling
- AJAX error handling with user-friendly messages
- Form validation before submission
- Modal state management

## Backward Compatibility

This implementation maintains full backward compatibility:
- Existing invoices continue to work unchanged
- Existing customer relationships preserved
- Existing product relationships preserved
- No breaking changes to existing functionality

## Future Enhancements

Potential future improvements:
1. Customer search/filtering in dropdown
2. Product search/filtering capabilities
3. Bulk customer/product import
4. Customer/product analytics
5. Integration with inventory management
6. Advanced pricing rules

## Testing Recommendations

1. **Create SalesCustomer**: Test modal form submission and dropdown update
2. **Create SalesProduct**: Test modal form submission and dropdown update
3. **Mixed Invoice**: Create invoice with both customer types and product types
4. **Validation**: Test form validation and error handling
5. **Backward Compatibility**: Ensure existing invoices still work
6. **AJAX Functionality**: Test modal forms and real-time updates