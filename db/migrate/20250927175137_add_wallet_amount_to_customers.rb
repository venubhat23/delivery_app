class AddWalletAmountToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :wallet_amount, :decimal, precision: 10, scale: 2, default: 50.0, null: false
  end
end
