class CreateReferrals < ActiveRecord::Migration[8.0]
  def change
    create_table :referrals do |t|
      t.references :affiliate, null: false, foreign_key: true
      t.string :customer_name
      t.string :customer_phone
      t.string :customer_email
      t.string :status
      t.decimal :reward_amount
      t.text :notes
      t.datetime :referred_at
      t.datetime :approved_at
      t.datetime :rejected_at

      t.timestamps
    end
  end
end
