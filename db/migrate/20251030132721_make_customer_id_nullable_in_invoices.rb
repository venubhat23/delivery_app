class MakeCustomerIdNullableInInvoices < ActiveRecord::Migration[8.0]
  def change
    change_column_null :invoices, :customer_id, true
  end
end
