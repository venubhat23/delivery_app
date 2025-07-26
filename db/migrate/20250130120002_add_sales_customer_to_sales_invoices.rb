class AddSalesCustomerToSalesInvoices < ActiveRecord::Migration[8.0]
  def change
    add_reference :sales_invoices, :sales_customer, null: true, foreign_key: true
  end
end