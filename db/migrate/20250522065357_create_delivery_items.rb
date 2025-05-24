class CreateDeliveryItems < ActiveRecord::Migration[8.0]
  def change
    create_table :delivery_items do |t|
      t.references :delivery, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity

      t.timestamps
    end
  end
end
