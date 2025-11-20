class AddFranchiseToDeliveryAssignments < ActiveRecord::Migration[8.0]
  def change
    add_reference :delivery_assignments, :franchise, null: true, foreign_key: true
  end
end
