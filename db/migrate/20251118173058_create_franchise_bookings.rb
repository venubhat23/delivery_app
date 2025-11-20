class CreateFranchiseBookings < ActiveRecord::Migration[8.0]
  def change
    create_table :franchise_bookings do |t|
      t.references :franchise, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity
      t.decimal :price
      t.string :status
      t.date :booking_date
      t.text :notes

      t.timestamps
    end
  end
end
