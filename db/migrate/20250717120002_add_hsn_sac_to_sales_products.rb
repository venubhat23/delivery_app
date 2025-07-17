class AddHsnSacToSalesProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :sales_products, :hsn_sac, :string
    add_column :sales_products, :tax_rate, :decimal, precision: 5, scale: 2, default: 0.0
  end
end