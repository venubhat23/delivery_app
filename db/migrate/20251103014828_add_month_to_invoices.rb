class AddMonthToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :month, :integer
  end
end
