class CreateProcurementInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :procurement_invoices do |t|
      t.references :user, null: false, foreign_key: true
      t.references :procurement_schedule, null: false, foreign_key: true
      t.string :invoice_number, null: false
      t.date :invoice_date, null: false
      t.date :due_date
      t.string :status, default: 'draft', null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false, default: 0
      t.string :vendor_name, null: false
      t.text :invoice_data
      t.text :notes

      t.timestamps
    end

    add_index :procurement_invoices, :invoice_number, unique: true
    add_index :procurement_invoices, :status
    add_index :procurement_invoices, :vendor_name
    add_index :procurement_invoices, :invoice_date
  end
end
