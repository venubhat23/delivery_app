class AddTotalAmountIndexToInvoices < ActiveRecord::Migration[8.0]
  def change
    # Add composite index for sorting by total_amount and created_at
    add_index :invoices, [:total_amount, :created_at], name: 'index_invoices_on_total_amount_and_created_at'

    # Add individual index for total_amount sorting
    add_index :invoices, :total_amount, name: 'index_invoices_on_total_amount'
  end
end
