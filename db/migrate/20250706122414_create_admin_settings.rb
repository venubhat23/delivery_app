class CreateAdminSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_settings do |t|
      t.string :business_name
      t.text :address
      t.string :mobile
      t.string :email
      t.string :gstin
      t.string :pan_number
      t.string :account_holder_name
      t.string :bank_name
      t.string :account_number
      t.string :ifsc_code
      t.string :upi_id
      t.text :terms_and_conditions
      t.string :qr_code_path

      t.timestamps
    end
  end
end
