class AddCustomerDetailsPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Critical indexes for customer details page performance

    # Optimize customer interval_days filtering (regular vs interval customers)
    add_index :customers, :interval_days, name: 'index_customers_interval_days'

    # Composite index for customer ordering with interval filtering
    add_index :customers, [:interval_days, :name], name: 'index_customers_interval_name'

    # Optimize delivery assignment customer lookups with created_at for recent assignments
    add_index :delivery_assignments, [:customer_id, :created_at],
              name: 'index_delivery_assignments_customer_created_at'

    # Optimize DISTINCT ON queries for recent assignments
    add_index :delivery_assignments, [:customer_id, :created_at, :id],
              name: 'index_delivery_assignments_customer_created_id'

    # Speed up user lookups in delivery assignments
    add_index :delivery_assignments, [:user_id, :customer_id],
              name: 'index_delivery_assignments_user_customer'

    # Optimize product lookups in delivery assignments
    add_index :delivery_assignments, [:product_id, :customer_id],
              name: 'index_delivery_assignments_product_customer'
  end
end
