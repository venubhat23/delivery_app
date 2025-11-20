class CreateFranchises < ActiveRecord::Migration[8.0]
  def change
    create_table :franchises do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone, null: false
      t.string :password_digest, null: false
      t.string :location, null: false
      t.string :gst_number
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :franchises, :email, unique: true
    add_index :franchises, :active
  end
end
