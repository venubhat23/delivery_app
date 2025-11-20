class CreateAffiliates < ActiveRecord::Migration[8.0]
  def change
    create_table :affiliates do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.string :password_digest
      t.string :location
      t.decimal :commission_rate
      t.decimal :total_earnings
      t.string :status
      t.boolean :active
      t.string :referral_code

      t.timestamps
    end
  end
end
