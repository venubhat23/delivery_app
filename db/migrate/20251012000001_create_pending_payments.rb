class CreatePendingPayments < ActiveRecord::Migration[7.0]
  def change
    create_table :pending_payments do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :month, null: false
      t.integer :year, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, default: 'pending', null: false
      t.text :notes
      t.datetime :paid_at

      t.timestamps
    end

    add_index :pending_payments, [:customer_id, :month, :year], unique: true
    add_index :pending_payments, :status
    add_index :pending_payments, [:month, :year]
  end
end