class AddProductToDeliverySchedules < ActiveRecord::Migration[8.0]
  def change
    add_reference :delivery_schedules, :product, null: true, foreign_key: true unless column_exists?(:delivery_schedules, :product_id)
  end
end
