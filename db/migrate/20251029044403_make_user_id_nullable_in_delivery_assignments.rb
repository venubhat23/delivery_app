class MakeUserIdNullableInDeliveryAssignments < ActiveRecord::Migration[8.0]
  def change
    change_column_null :delivery_assignments, :user_id, true
  end
end
