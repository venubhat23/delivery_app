class AddProductIdToProcurementSchedules < ActiveRecord::Migration[8.0]
  def change
    add_reference :procurement_schedules, :product, null: true, foreign_key: true
  end
end
