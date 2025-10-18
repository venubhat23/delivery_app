class AddPerformanceIndexesToProcurementTables < ActiveRecord::Migration[8.0]
  def change
    # Indexes for procurement_schedules table
    add_index :procurement_schedules, [:user_id, :from_date, :to_date],
              name: 'index_procurement_schedules_on_user_dates'
    add_index :procurement_schedules, [:vendor_name, :from_date],
              name: 'index_procurement_schedules_on_vendor_date'
    add_index :procurement_schedules, :status

    # Indexes for procurement_assignments table
    add_index :procurement_assignments, [:procurement_schedule_id, :status],
              name: 'index_procurement_assignments_on_schedule_status'
    add_index :procurement_assignments, [:procurement_schedule_id, :date],
              name: 'index_procurement_assignments_on_schedule_date'
    add_index :procurement_assignments, [:date, :status],
              name: 'index_procurement_assignments_on_date_status'

    # Composite index for the bulk calculation query
    add_index :procurement_assignments,
              [:procurement_schedule_id, :actual_quantity, :planned_quantity, :buying_price],
              name: 'index_procurement_assignments_for_amount_calc'
  end
end
