class AddIndexesToOptimizeDashboardQueries < ActiveRecord::Migration[8.0]
  def change
    # Optimize delivery_assignments queries
    add_index :delivery_assignments, [:status, :scheduled_date], name: 'idx_delivery_status_scheduled_date'
    add_index :delivery_assignments, [:status, :completed_at], name: 'idx_delivery_status_completed_at'
    add_index :delivery_assignments, [:product_id, :status, :scheduled_date], name: 'idx_delivery_product_status_date'
    add_index :delivery_assignments, [:product_id, :status, :completed_at], name: 'idx_delivery_product_status_completed'

    # Optimize products queries
    add_index :products, :unit_type, name: 'idx_products_unit_type'
    add_index :products, :name, name: 'idx_products_name'

    # Optimize customers queries
    add_index :customers, :created_at, name: 'idx_customers_created_at'
  end
end
