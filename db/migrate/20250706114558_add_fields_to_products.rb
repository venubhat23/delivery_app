class AddFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :image_url, :string
    add_column :products, :sku, :string
    add_column :products, :stock_alert_threshold, :integer
    add_column :products, :is_subscription_eligible, :boolean, default: false
    add_column :products, :is_active, :boolean, default: true
  end
end