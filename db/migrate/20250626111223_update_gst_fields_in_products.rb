class UpdateGstFieldsInProducts < ActiveRecord::Migration[8.0]
  def change
    # Remove old GST fields if they exist
    remove_column :products, :gst_percentage, :decimal if column_exists?(:products, :gst_percentage)
    remove_column :products, :cgst_value, :decimal if column_exists?(:products, :cgst_value)
    remove_column :products, :sgst_value, :decimal if column_exists?(:products, :sgst_value)
    remove_column :products, :total_gst_value, :decimal if column_exists?(:products, :total_gst_value)

    # Add new GST fields
    add_column :products, :total_gst_percentage, :decimal, precision: 5, scale: 2
    add_column :products, :total_cgst_percentage, :decimal, precision: 5, scale: 2
    add_column :products, :total_sgst_percentage, :decimal, precision: 5, scale: 2
    add_column :products, :total_igst_percentage, :decimal, precision: 5, scale: 2
  end
end