class CreateProcurementAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :procurement_assignments do |t|
      t.references :procurement_schedule, null: false, foreign_key: true
      t.string :vendor_name, null: false
      t.date :date, null: false
      t.decimal :planned_quantity, precision: 10, scale: 2, null: false
      t.decimal :actual_quantity, precision: 10, scale: 2
      t.decimal :buying_price, precision: 10, scale: 2, null: false
      t.decimal :selling_price, precision: 10, scale: 2, null: false
      t.string :status, default: 'pending'
      t.text :notes
      t.string :unit, default: 'liters'
      t.references :user, null: false, foreign_key: true
      t.datetime :completed_at

      t.timestamps
    end

    add_index :procurement_assignments, :vendor_name
    add_index :procurement_assignments, :date
    add_index :procurement_assignments, :status
    add_index :procurement_assignments, [:date, :vendor_name]
    add_index :procurement_assignments, :procurement_schedule_id
    add_index :procurement_assignments, :user_id
  end
end