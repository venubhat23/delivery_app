class ChangeTotalAmountToFloatInInvoices < ActiveRecord::Migration[6.0] # or your current version
  def change
    change_column :invoices, :total_amount, :float
  end
end
