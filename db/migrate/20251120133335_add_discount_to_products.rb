class AddDiscountToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :price_without_discount, :decimal, precision: 10, scale: 2
    add_column :products, :discount, :decimal, precision: 5, scale: 2, default: 0
  end
end
