class CreatePurchaseInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    create_table :purchase_invoice_items do |t|
      t.references :purchase_invoice, null: false, foreign_key: true
      t.references :purchase_product, null: false, foreign_key: true
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :tax_rate, precision: 5, scale: 2, default: 0
      t.decimal :discount, precision: 10, scale: 2, default: 0
      t.decimal :amount, precision: 10, scale: 2, null: false
      
      t.timestamps
    end
    
    add_index :purchase_invoice_items, [:purchase_invoice_id, :purchase_product_id], 
              name: 'index_purchase_items_on_invoice_and_product'
  end
end
