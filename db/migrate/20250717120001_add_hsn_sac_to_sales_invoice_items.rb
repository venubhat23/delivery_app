class AddHsnSacToSalesInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    add_column :sales_invoice_items, :hsn_sac, :string
  end
end