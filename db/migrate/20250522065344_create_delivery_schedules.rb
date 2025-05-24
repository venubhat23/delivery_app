class CreateDeliverySchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_schedules do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :frequency
      t.date :start_date
      t.date :end_date
      t.string :status

      t.timestamps
    end
  end
end
