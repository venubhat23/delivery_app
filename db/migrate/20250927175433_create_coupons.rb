class CreateCoupons < ActiveRecord::Migration[8.0]
  def change
    create_table :coupons do |t|
      t.string :code
      t.decimal :amount
      t.text :description
      t.datetime :expires_at
      t.string :status

      t.timestamps
    end
  end
end
