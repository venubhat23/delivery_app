class ChangeDeliveryScheduleIdToBeNullableInDeliveryAssignments < ActiveRecord::Migration[6.1]
  def change
    change_column_null :delivery_assignments, :delivery_schedule_id, true
  end
end
