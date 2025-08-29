class AddCommonSettingsToAdminSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :admin_settings, :faq, :text
    add_column :admin_settings, :contact_us, :text
    add_column :admin_settings, :privacy_policy, :text
  end
end
