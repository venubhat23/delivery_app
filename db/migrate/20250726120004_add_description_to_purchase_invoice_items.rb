class AddDescriptionAndHsnToPurchaseInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    add_column :purchase_invoice_items, :description, :text
    add_column :purchase_invoice_items, :hsn_sac, :string
  end
end