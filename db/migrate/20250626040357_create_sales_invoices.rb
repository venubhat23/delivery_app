
# db/migrate/xxx_create_sales_invoices.rb
class CreateSalesInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :sales_invoices do |t|
      t.string :invoice_number, null: false
      t.string :invoice_type, null: false
      t.string :customer_name, null: false
      t.date :invoice_date, null: false
      t.date :due_date
      t.integer :payment_terms, default: 30
      t.decimal :subtotal, precision: 10, scale: 2, default: 0.0
      t.decimal :tax_amount, precision: 10, scale: 2, default: 0.0
      t.decimal :discount_amount, precision: 10, scale: 2, default: 0.0
      t.decimal :total_amount, precision: 10, scale: 2, default: 0.0
      t.decimal :amount_paid, precision: 10, scale: 2, default: 0.0
      t.decimal :balance_amount, precision: 10, scale: 2, default: 0.0
      t.string :status, default: 'pending'
      t.text :notes
      t.timestamps
    end

    add_index :sales_invoices, :invoice_number
    add_index :sales_invoices, :invoice_type
    add_index :sales_invoices, :customer_name
    add_index :sales_invoices, :status
  end
end
