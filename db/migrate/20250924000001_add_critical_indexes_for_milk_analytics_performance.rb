class AddCriticalIndexesForMilkAnalyticsPerformance < ActiveRecord::Migration[8.0]
  def change
    # Critical composite index for procurement_assignments queries
    add_index :procurement_assignments, [:user_id, :date, :product_id],
              name: 'idx_proc_assignments_user_date_product'

    # Index for date range queries with vendor filtering
    add_index :procurement_assignments, [:date, :vendor_name, :planned_quantity],
              name: 'idx_proc_assignments_date_vendor_quantity'

    # Critical composite index for delivery_assignments queries
    add_index :delivery_assignments, [:scheduled_date, :status, :product_id],
              name: 'idx_delivery_assignments_date_status_product'

    # Index for revenue calculations in delivery assignments
    add_index :delivery_assignments, [:scheduled_date, :final_amount_after_discount, :quantity],
              name: 'idx_delivery_assignments_date_revenue_qty'

    # Index for GROUP BY queries on date
    add_index :procurement_assignments, [:date, :planned_quantity, :buying_price],
              name: 'idx_proc_assignments_date_quantity_price'

    # Index for delivery GROUP BY queries
    add_index :delivery_assignments, [:scheduled_date, :quantity, :final_amount_after_discount],
              name: 'idx_delivery_assignments_date_qty_amount'

    # Partial index for completed deliveries only (most common filter)
    add_index :delivery_assignments, [:scheduled_date, :product_id, :quantity],
              where: "status = 'completed'",
              name: 'idx_delivery_assignments_completed_date_product'
  end
end