class UpdateExistingProductPrices < ActiveRecord::Migration[8.0]
  def up
    # Update all existing products where price_without_discount is null
    # Set price_without_discount to current price and discount to 0
    Product.where(price_without_discount: nil).find_each do |product|
      product.update_columns(
        price_without_discount: product.price,
        discount: 0
      )
    end
  end

  def down
    # Rollback: set price_without_discount to null for products with 0 discount
    Product.where(discount: 0).update_all(price_without_discount: nil)
  end
end
