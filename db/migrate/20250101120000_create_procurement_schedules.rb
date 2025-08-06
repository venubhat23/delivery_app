class CreateProcurementSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :procurement_schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.string :vendor_name, null: false
      t.date :from_date, null: false
      t.date :to_date, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :buying_price, precision: 10, scale: 2, null: false
      t.decimal :selling_price, precision: 10, scale: 2, null: false
      t.string :unit, default: 'liters', null: false
      t.string :status, default: 'active', null: false
      t.text :notes

      t.timestamps
    end

    add_index :procurement_schedules, :user_id
    add_index :procurement_schedules, :vendor_name
    add_index :procurement_schedules, :status
    add_index :procurement_schedules, [:from_date, :to_date]
  end
end