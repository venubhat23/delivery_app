class EnhancePurchaseInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :purchase_invoices, :original_invoice_number, :string
    add_column :purchase_invoices, :bill_from, :text
    add_column :purchase_invoices, :ship_from, :text
    add_column :purchase_invoices, :additional_charges, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :purchase_invoices, :additional_discount, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :purchase_invoices, :auto_round_off, :boolean, default: false
    add_column :purchase_invoices, :round_off_amount, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :purchase_invoices, :payment_type, :string, default: 'cash'
    add_column :purchase_invoices, :terms_and_conditions, :text
    add_column :purchase_invoices, :authorized_signature, :text
    
    # Remove the invoice_type column as it's no longer needed for purchase invoices
    remove_column :purchase_invoices, :invoice_type, :string if column_exists?(:purchase_invoices, :invoice_type)
    
    add_index :purchase_invoices, :original_invoice_number
    add_index :purchase_invoices, :payment_type
  end
end