class AddProductIdToProcurementAssignments < ActiveRecord::Migration[8.0]
  def change
    add_reference :procurement_assignments, :product, null: true, foreign_key: true
  end
end
