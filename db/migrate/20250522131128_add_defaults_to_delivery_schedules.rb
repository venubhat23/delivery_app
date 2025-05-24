class AddDefaultsToDeliverySchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :delivery_schedules, :default_quantity, :decimal, precision: 8, scale: 2, default: 1.0
    add_column :delivery_schedules, :default_unit, :string, default: 'pieces'
  end
end
