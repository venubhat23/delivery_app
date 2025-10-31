class AddQuickInvoiceFieldsToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :quick_customer_name, :string
    add_column :invoices, :quick_customer_phone_number, :string
    add_column :invoices, :is_quick_invoice, :boolean, default: false
  end
end
