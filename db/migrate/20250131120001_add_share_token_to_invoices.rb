class AddShareTokenToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :share_token, :string
    add_column :invoices, :shared_at, :datetime
    
    add_index :invoices, :share_token, unique: true
  end
end