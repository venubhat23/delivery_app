class AddFieldsToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :email, :string
    add_column :customers, :gst_number, :string
    add_column :customers, :pan_number, :string
    add_column :customers, :member_id, :string
    add_column :customers, :shipping_address, :string
  end
end
