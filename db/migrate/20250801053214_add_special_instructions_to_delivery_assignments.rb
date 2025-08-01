class AddSpecialInstructionsToDeliveryAssignments < ActiveRecord::Migration[8.0]
  def change
    add_column :delivery_assignments, :special_instructions, :text
  end
end
