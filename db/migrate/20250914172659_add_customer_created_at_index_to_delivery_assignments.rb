class AddCustomerCreatedAtIndexToDeliveryAssignments < ActiveRecord::Migration[8.0]
  def change
    # Add index to optimize the DISTINCT ON query for recent assignments
    add_index :delivery_assignments, [:customer_id, :created_at],
              name: 'index_delivery_assignments_on_customer_and_created_at'

    # Add index to optimize queries by interval_days for customer categorization
    add_index :customers, :interval_days,
              name: 'index_customers_on_interval_days'
  end
end
