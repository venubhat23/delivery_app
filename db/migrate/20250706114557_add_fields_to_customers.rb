class AddFieldsToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :preferred_language, :string
    add_column :customers, :delivery_time_preference, :string
    add_column :customers, :notification_method, :string
    add_column :customers, :alt_phone_number, :string
    add_column :customers, :profile_image_url, :string
    add_column :customers, :address_landmark, :string
    add_column :customers, :address_type, :string
    add_column :customers, :is_active, :boolean, default: true
  end
end