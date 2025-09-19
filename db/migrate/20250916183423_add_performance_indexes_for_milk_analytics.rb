class AddPerformanceIndexesForMilkAnalytics < ActiveRecord::Migration[8.0]
  def change
    # Critical indexes for milk analytics performance

    # Improve delivery_assignments date range queries with revenue calculations
    add_index :delivery_assignments, [:scheduled_date, :final_amount_after_discount],
              name: 'index_delivery_assignments_date_revenue'

    # Improve customer lookups in delivery assignments
    add_index :delivery_assignments, [:customer_id, :scheduled_date, :status],
              name: 'index_delivery_assignments_customer_date_status'

    # Optimize product-based filtering
    add_index :delivery_assignments, [:product_id, :scheduled_date, :quantity],
              name: 'index_delivery_assignments_product_date_quantity'

    # Improve user-based procurement queries
    add_index :procurement_assignments, [:user_id, :date, :vendor_name],
              name: 'index_procurement_assignments_user_date_vendor'

    # Speed up revenue calculations
    add_index :delivery_assignments, [:scheduled_date, :quantity, :final_amount_after_discount],
              name: 'index_delivery_assignments_date_qty_revenue'

    # Optimize product category joins frequently used in analytics
    add_index :products, [:category_id, :name], name: 'index_products_category_name'

    # Improve customer delivery person lookups
    add_index :customers, [:delivery_person_id, :is_active],
              name: 'index_customers_delivery_person_active'
  end
end
