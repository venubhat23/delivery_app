class AddInvoicesCountToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :invoices_count, :integer, default: 0, null: false

    # Reset counter cache for existing customers after column is added
    reversible do |dir|
      dir.up do
        # This will be run manually after migration if needed
        # Customer.find_each { |customer| Customer.reset_counters(customer.id, :invoices) }
      end
    end
  end
end
