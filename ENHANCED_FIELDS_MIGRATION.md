# Enhanced Fields Migration Documentation

## Overview
This migration adds enhanced fields to both customers and products tables to improve functionality and data collection capabilities.

## Migration Files Created

### 1. `20250706114557_add_fields_to_customers.rb`
Adds the following fields to the `customers` table:

#### New Customer Fields:
- **`preferred_language`** (string): Customer's preferred language for communication
- **`delivery_time_preference`** (string): Customer's preferred delivery time slot
- **`notification_method`** (string): Preferred method for notifications (SMS, email, push, etc.)
- **`alt_phone_number`** (string): Alternative phone number for contact
- **`profile_image_url`** (string): URL for customer's profile image
- **`address_landmark`** (string): Landmark near the customer's address
- **`address_type`** (string): Type of address (home, office, etc.)
- **`is_active`** (boolean): Customer active status (default: true)

### 2. `20250706114558_add_fields_to_products.rb`
Adds the following fields to the `products` table:

#### New Product Fields:
- **`image_url`** (string): URL for product image
- **`sku`** (string): Stock Keeping Unit identifier
- **`stock_alert_threshold`** (integer): Minimum stock level for alerts
- **`is_subscription_eligible`** (boolean): Whether product can be part of subscriptions (default: false)
- **`is_active`** (boolean): Product active status (default: true)

## Technical Details

### Migration Structure
Both migrations follow Rails 8.0 conventions:
```ruby
class AddFieldsToCustomers < ActiveRecord::Migration[8.0]
  def change
    # add_column statements
  end
end
```

### Default Values
- Boolean fields have appropriate default values:
  - `customers.is_active` defaults to `true`
  - `products.is_active` defaults to `true`
  - `products.is_subscription_eligible` defaults to `false`

## Business Benefits

### Customer Enhancements:
1. **Better Communication**: Preferred language and notification method
2. **Improved Delivery**: Delivery time preferences and address landmarks
3. **Enhanced Contact**: Alternative phone number for better reachability
4. **User Experience**: Profile images for better interface
5. **Data Management**: Active status for soft deletes

### Product Enhancements:
1. **Inventory Management**: Stock alert thresholds for automated alerts
2. **Visual Appeal**: Product images for better user experience
3. **SKU Management**: Unique identifiers for inventory tracking
4. **Subscription Services**: Eligibility flags for subscription products
5. **Catalog Management**: Active status for product lifecycle management

## Usage Examples

### Customer Fields:
```ruby
customer = Customer.new(
  name: "John Doe",
  preferred_language: "English",
  delivery_time_preference: "Morning (9AM-12PM)",
  notification_method: "SMS",
  alt_phone_number: "+1234567890",
  address_landmark: "Near City Mall",
  address_type: "Home",
  is_active: true
)
```

### Product Fields:
```ruby
product = Product.new(
  name: "Organic Milk",
  image_url: "https://example.com/milk.jpg",
  sku: "ORG-MILK-001",
  stock_alert_threshold: 10,
  is_subscription_eligible: true,
  is_active: true
)
```

## Database Schema Changes

### Customers Table (After Migration):
```sql
-- New columns added:
ALTER TABLE customers ADD COLUMN preferred_language VARCHAR;
ALTER TABLE customers ADD COLUMN delivery_time_preference VARCHAR;
ALTER TABLE customers ADD COLUMN notification_method VARCHAR;
ALTER TABLE customers ADD COLUMN alt_phone_number VARCHAR;
ALTER TABLE customers ADD COLUMN profile_image_url VARCHAR;
ALTER TABLE customers ADD COLUMN address_landmark VARCHAR;
ALTER TABLE customers ADD COLUMN address_type VARCHAR;
ALTER TABLE customers ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
```

### Products Table (After Migration):
```sql
-- New columns added:
ALTER TABLE products ADD COLUMN image_url VARCHAR;
ALTER TABLE products ADD COLUMN sku VARCHAR;
ALTER TABLE products ADD COLUMN stock_alert_threshold INTEGER;
ALTER TABLE products ADD COLUMN is_subscription_eligible BOOLEAN DEFAULT FALSE;
ALTER TABLE products ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
```

## Migration Commands

To run these migrations:
```bash
# Run migrations
rails db:migrate

# Rollback if needed
rails db:rollback STEP=2

# Check migration status
rails db:migrate:status
```

## Model Updates Required

After running these migrations, consider updating the respective models:

### Customer Model (`app/models/customer.rb`):
```ruby
class Customer < ApplicationRecord
  # Add validations for new fields
  validates :preferred_language, inclusion: { in: %w[English Spanish French] }, allow_blank: true
  validates :delivery_time_preference, inclusion: { in: %w[Morning Afternoon Evening] }, allow_blank: true
  validates :notification_method, inclusion: { in: %w[SMS Email Push] }, allow_blank: true
  validates :address_type, inclusion: { in: %w[Home Office Other] }, allow_blank: true
  
  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
end
```

### Product Model (`app/models/product.rb`):
```ruby
class Product < ApplicationRecord
  # Add validations for new fields
  validates :sku, uniqueness: true, allow_blank: true
  validates :stock_alert_threshold, numericality: { greater_than: 0 }, allow_blank: true
  
  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :subscription_eligible, -> { where(is_subscription_eligible: true) }
  scope :low_stock, -> { where('stock_quantity <= stock_alert_threshold') }
end
```

## Testing Considerations

1. **Migration Tests**: Ensure migrations run without errors
2. **Field Validation**: Test new field validations
3. **Default Values**: Verify default values are applied correctly
4. **Backward Compatibility**: Ensure existing functionality remains intact

## Future Enhancements

These new fields enable:
1. **Advanced Filtering**: Filter customers/products by new attributes
2. **Automated Notifications**: Use notification preferences
3. **Inventory Alerts**: Automated stock alerts
4. **Subscription Management**: Product eligibility for subscriptions
5. **Enhanced UI/UX**: Better user interfaces with images and preferences

## Git Information

- **Branch**: `test1`
- **Commit**: `d6f0623` - "Add enhanced fields to customers and products"
- **Pull Request**: Create at https://github.com/venubhat23/delivery_app/pull/new/test1

## Files Modified

1. `db/migrate/20250706114557_add_fields_to_customers.rb` - Customer fields migration
2. `db/migrate/20250706114558_add_fields_to_products.rb` - Product fields migration
3. `ENHANCED_FIELDS_MIGRATION.md` - This documentation

## Review Checklist

- [ ] Migration files syntax is correct
- [ ] Default values are appropriate
- [ ] Field names follow Rails conventions
- [ ] Documentation is comprehensive
- [ ] Migration is reversible
- [ ] No breaking changes to existing functionality