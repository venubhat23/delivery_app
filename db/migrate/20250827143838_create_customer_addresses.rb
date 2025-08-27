class CreateCustomerAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_addresses do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :address_type
      t.text :street_address
      t.string :city
      t.string :state
      t.string :pincode
      t.string :landmark
      t.boolean :is_default

      t.timestamps
    end
  end
end
