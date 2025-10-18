class AddAdditionalProcurementIndexes < ActiveRecord::Migration[8.0]
  def change
    # Additional indexes for procurement_schedules optimizations
    add_index :procurement_schedules, [:user_id, :status, :created_at],
              name: 'index_procurement_schedules_user_status_created'

    # Index for procurement_invoices lookup optimization
    add_index :procurement_invoices, [:procurement_schedule_id, :created_at],
              name: 'index_procurement_invoices_schedule_created'
    add_index :procurement_invoices, [:status, :created_at],
              name: 'index_procurement_invoices_status_created'

    # Optimize the assignment queries with additional indexes
    add_index :procurement_assignments, [:updated_at],
              name: 'index_procurement_assignments_updated_at'
    add_index :procurement_assignments, [:procurement_schedule_id, :updated_at],
              name: 'index_procurement_assignments_schedule_updated'

    # Composite index for user schedules with time filtering
    add_index :procurement_schedules, [:user_id, :from_date, :to_date, :status],
              name: 'index_procurement_schedules_user_dates_status'
  end
end
