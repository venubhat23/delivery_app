# db/migrate/add_fields_to_invoices.rb
class AddFieldsToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :invoice_number, :string
    add_column :invoices, :invoice_type, :string, default: 'manual'
    add_column :invoices, :paid_at, :datetime
    add_column :invoices, :last_reminder_sent_at, :datetime
    add_column :invoices, :notes, :text
    
    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, :status
    add_index :invoices, :invoice_date
    add_index :invoices, :due_date
    add_index :invoices, :invoice_type
  end
end