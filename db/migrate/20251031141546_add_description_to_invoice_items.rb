class AddDescriptionToInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    add_column :invoice_items, :description, :string
  end
end
