class AddCustomerSpecificSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :customer_preferences, :referral_code, :string
    add_column :customer_preferences, :referral_earnings, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :customer_preferences, :address_request_notes, :text
    add_column :customer_preferences, :referral_enabled, :boolean, default: true
  end
end
