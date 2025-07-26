class CreateSalesCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :sales_customers do |t|
      t.string :name, null: false
      t.text :address
      t.string :city
      t.string :state
      t.string :pincode
      t.string :phone_number, null: false
      t.string :email
      t.string :gst_number
      t.string :pan_number
      t.string :contact_person
      t.text :shipping_address
      t.boolean :is_active, default: true
      
      t.timestamps
    end
    
    add_index :sales_customers, :name, unique: true
    add_index :sales_customers, :is_active
    add_index :sales_customers, :gst_number
  end
end