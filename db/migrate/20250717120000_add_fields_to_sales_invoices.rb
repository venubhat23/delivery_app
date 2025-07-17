class AddFieldsToSalesInvoices < ActiveRecord::Migration[8.0]
  def change
    add_reference :sales_invoices, :customer, null: true, foreign_key: true
    add_column :sales_invoices, :bill_to, :text
    add_column :sales_invoices, :ship_to, :text
    add_column :sales_invoices, :additional_charges, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :sales_invoices, :additional_discount, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :sales_invoices, :apply_tcs, :boolean, default: false
    add_column :sales_invoices, :tcs_rate, :decimal, precision: 5, scale: 2, default: 0.0
    add_column :sales_invoices, :auto_round_off, :boolean, default: false
    add_column :sales_invoices, :round_off_amount, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :sales_invoices, :payment_type, :string, default: 'cash'
    add_column :sales_invoices, :terms_and_conditions, :text
    add_column :sales_invoices, :authorized_signature, :text
  end
end