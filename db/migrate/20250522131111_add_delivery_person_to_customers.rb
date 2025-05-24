class AddDeliveryPersonToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_reference :customers, :delivery_person, null: true, foreign_key: { to_table: :users }
  end
end

