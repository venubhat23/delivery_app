class AddUniquenessIndexToProcurementAssignments < ActiveRecord::Migration[8.0]
  def change
    # Add unique index for the uniqueness validation
    add_index :procurement_assignments,
              [:date, :procurement_schedule_id, :vendor_name],
              unique: true,
              name: 'index_procurement_assignments_unique_date_schedule_vendor'

    # Add specific index for user assignments lookup
    add_index :procurement_assignments, [:user_id, :id],
              name: 'index_procurement_assignments_user_id'

    # Add index for vendor name filtering
    add_index :procurement_assignments, [:vendor_name, :status, :date],
              name: 'index_procurement_assignments_vendor_status_date'
  end
end
