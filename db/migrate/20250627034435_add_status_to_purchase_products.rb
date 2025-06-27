
# db/migrate/XXXXXXXXXX_add_status_to_purchase_products.rb
class AddStatusToPurchaseProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :purchase_products, :status, :string, default: "unpaid", null: false
    add_index :purchase_products, :status
  end
end