class CreateProcurementSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :procurement_schedules do |t|
      t.string :vendor_name, null: false
      t.date :from_date, null: false
      t.date :to_date, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :buying_price, precision: 10, scale: 2, null: false
      t.decimal :selling_price, precision: 10, scale: 2, null: false
      t.string :status, default: 'active'
      t.string :unit, default: 'liters'
      t.text :notes
      t.string :whatsapp_phone_number
      t.references :user, null: false, foreign_key: true
      t.references :product, null: true, foreign_key: true

      t.timestamps
    end

    add_index :procurement_schedules, :vendor_name
    add_index :procurement_schedules, :status
    add_index :procurement_schedules, [:from_date, :to_date]
    add_index :procurement_schedules, [:user_id, :vendor_name]
  end
end
