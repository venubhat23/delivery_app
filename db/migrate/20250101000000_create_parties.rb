class CreateParties < ActiveRecord::Migration[8.0]
  def change
    create_table :parties do |t|
      t.string :name, null: false
      t.string :mobile_number, null: false
      t.string :gst_number
      t.text :shipping_address
      t.string :shipping_pincode
      t.string :shipping_city
      t.string :shipping_state
      t.text :billing_address
      t.string :billing_pincode
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :parties, :name
    add_index :parties, :mobile_number
    add_index :parties, :gst_number
  end
end