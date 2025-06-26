class AddGstFieldsToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :is_gst_applicable, :boolean, default: false
    add_column :products, :gst_percentage, :decimal, precision: 5, scale: 2
    add_column :products, :cgst_value, :decimal, precision: 10, scale: 2
    add_column :products, :sgst_value, :decimal, precision: 10, scale: 2
    add_column :products, :total_gst_value, :decimal, precision: 10, scale: 2
  end
end