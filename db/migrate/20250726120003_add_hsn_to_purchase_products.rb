class AddHsnToPurchaseProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :purchase_products, :hsn_sac, :string
    add_column :purchase_products, :tax_rate, :decimal, precision: 5, scale: 2, default: 0.0
    
    add_index :purchase_products, :hsn_sac
  end
end