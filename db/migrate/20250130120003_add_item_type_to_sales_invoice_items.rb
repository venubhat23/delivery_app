class AddItemTypeToSalesInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    add_column :sales_invoice_items, :item_type, :string, default: 'SalesProduct'
    add_reference :sales_invoice_items, :product, null: true, foreign_key: true
    
    add_index :sales_invoice_items, [:item_type, :sales_product_id]
    add_index :sales_invoice_items, [:item_type, :product_id]
  end
end