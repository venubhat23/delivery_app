class AddHsnSacToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :hsn_sac, :string
  end
end