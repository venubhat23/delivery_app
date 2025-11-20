class CreatePayouts < ActiveRecord::Migration[8.0]
  def change
    create_table :payouts do |t|
      t.string :name, null: false
      t.string :gst
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :transaction_id
      t.string :paid_via, null: false
      t.date :date, null: false
      t.text :description

      t.timestamps
    end

    add_index :payouts, :date
    add_index :payouts, :paid_via
    add_index :payouts, [:date, :paid_via]
  end
end