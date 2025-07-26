# Purchase Invoice Items Fix

## Issue
The application was throwing an error: `undefined method 'description' for #<PurchaseInvoiceItem>` when trying to render the purchase invoice form. This was happening because the form was trying to use a `description` attribute that didn't exist in the `PurchaseInvoiceItem` model.

Additionally, the form was also referencing an `hsn_sac` field that was missing from the `purchase_invoice_items` table.

## Root Cause
The `purchase_invoice_items` table was missing two columns that the forms were trying to use:
1. `description` - for item descriptions
2. `hsn_sac` - for HSN/SAC codes

## Solution

### 1. Database Migration
Created migration `20250726120004_add_description_and_hsn_to_purchase_invoice_items.rb` to add the missing columns:

```ruby
class AddDescriptionAndHsnToPurchaseInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    add_column :purchase_invoice_items, :description, :text
    add_column :purchase_invoice_items, :hsn_sac, :string
  end
end
```

### 2. Controller Updates
Updated `app/controllers/purchase_invoices_controller.rb` to permit the new parameters:

```ruby
purchase_invoice_items_attributes: [
  :id, :purchase_product_id, :quantity, :price, :tax_rate, :discount, :description, :hsn_sac, :_destroy
]
```

### 3. Model Updates
Updated `app/models/purchase_invoice_item.rb` to:
- Add `before_save :set_hsn_sac` callback to automatically populate HSN/SAC from the associated product
- Added `set_hsn_sac` method to copy HSN/SAC from the purchase product
- Removed the redundant `product_hsn` method since we now have the `hsn_sac` attribute directly

## Files Modified
1. `db/migrate/20250726120004_add_description_and_hsn_to_purchase_invoice_items.rb` (new)
2. `app/controllers/purchase_invoices_controller.rb`
3. `app/models/purchase_invoice_item.rb`

## Next Steps
To complete the fix, you need to run the migration:

```bash
rails db:migrate
```

This will add the missing columns to the database and resolve the error in the purchase invoice forms.

## Forms Affected
- `app/views/purchase_invoices/new.html.erb`
- `app/views/purchase_invoices/_form.html.erb`

Both forms use the `description` and `hsn_sac` fields for purchase invoice items, and these will now work correctly after the migration is run.