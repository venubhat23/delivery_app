class AddDiscountFieldsToDeliveryModels < ActiveRecord::Migration[8.0]
  def change
    # Add discount fields to delivery_assignments
    add_column :delivery_assignments, :discount_amount, :decimal, precision: 10, scale: 2, default: 0.0
    add_column :delivery_assignments, :final_amount_after_discount, :decimal, precision: 10, scale: 2
    
    # Add discount fields to delivery_schedules
    add_column :delivery_schedules, :default_discount_amount, :decimal, precision: 10, scale: 2, default: 0.0
    
    # Add indexes for better performance
    add_index :delivery_assignments, :discount_amount
    add_index :delivery_assignments, :final_amount_after_discount
    add_index :delivery_schedules, :default_discount_amount
  end
end