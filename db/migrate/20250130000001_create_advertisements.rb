class CreateAdvertisements < ActiveRecord::Migration[8.0]
  def change
    create_table :advertisements do |t|
      t.string :name, null: false
      t.string :image_url
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :status, default: 'active'
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :advertisements, :status
    add_index :advertisements, :start_date
    add_index :advertisements, :end_date
    add_index :advertisements, [:start_date, :end_date]
  end
end