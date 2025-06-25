class CreatePurchaseInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :purchase_invoices do |t|
      t.string :invoice_number, null: false
      t.string :invoice_type, null: false # 'purchase' or 'sales'
      t.string :party_name, null: false
      t.date :invoice_date, null: false
      t.date :due_date
      t.integer :payment_terms, default: 30
      t.decimal :subtotal, precision: 10, scale: 2, default: 0
      t.decimal :tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :discount_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_amount, precision: 10, scale: 2, default: 0
      t.decimal :amount_paid, precision: 10, scale: 2, default: 0
      t.decimal :balance_amount, precision: 10, scale: 2, default: 0
      t.string :status, default: 'unpaid' # 'paid', 'unpaid', 'partial'
      t.text :notes
      
      t.timestamps
    end
    
    add_index :purchase_invoices, :invoice_number
    add_index :purchase_invoices, :invoice_type
    add_index :purchase_invoices, :party_name
    add_index :purchase_invoices, :status
  end
end
