class MakeProductIdNullableInInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    change_column_null :invoice_items, :product_id, true
  end
end
