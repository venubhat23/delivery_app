class CreateSalesProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :sales_products do |t|
      t.string :name, null: false
      t.string :category
      t.decimal :purchase_price, precision: 10, scale: 2
      t.decimal :sales_price, precision: 10, scale: 2
      t.string :measuring_unit, default: 'PCS'
      t.integer :opening_stock, default: 0
      t.integer :current_stock, default: 0
      t.boolean :enable_serialization, default: false
      t.text :description
      t.timestamps
    end

    add_index :sales_products, :name
    add_index :sales_products, :category
  end
end