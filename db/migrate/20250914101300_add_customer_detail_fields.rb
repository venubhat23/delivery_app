class AddCustomerDetailFields < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :regular_quantity, :integer
    add_column :customers, :regular_product_id, :integer
    add_column :customers, :regular_delivery_person, :string
    add_column :customers, :regular_delivery_person_from_assignment, :string
  end
end
