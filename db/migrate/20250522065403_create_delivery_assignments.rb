class CreateDeliveryAssignments < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_assignments do |t|
      t.references :delivery_schedule, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :scheduled_date
      t.string :status
      t.datetime :completed_at
      t.references :product, null: false, foreign_key: true
      t.float :quantity
      t.string :unit

      t.timestamps
    end
  end
end
