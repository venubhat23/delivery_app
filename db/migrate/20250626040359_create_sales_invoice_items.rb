
# db/migrate/xxx_create_sales_invoice_items.rb
class CreateSalesInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    create_table :sales_invoice_items do |t|
      t.bigint :sales_invoice_id, null: false
      t.bigint :sales_product_id, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :tax_rate, precision: 5, scale: 2, default: 0.0
      t.decimal :discount, precision: 10, scale: 2, default: 0.0
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.timestamps
    end

    add_index :sales_invoice_items, [:sales_invoice_id, :sales_product_id], 
              name: 'index_sales_items_on_invoice_and_product'
    add_index :sales_invoice_items, :sales_invoice_id
    add_index :sales_invoice_items, :sales_product_id
  end
end