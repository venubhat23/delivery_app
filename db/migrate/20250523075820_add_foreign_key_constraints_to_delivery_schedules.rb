class AddForeignKeyConstraintsToDeliverySchedules < ActiveRecord::Migration[8.0]
  def change
    # Add foreign key constraints if they don't exist
    unless foreign_key_exists?(:delivery_schedules, :customers)
      add_foreign_key :delivery_schedules, :customers
    end
    
    unless foreign_key_exists?(:delivery_schedules, :users)
      add_foreign_key :delivery_schedules, :users
    end
    
    unless foreign_key_exists?(:delivery_schedules, :products)
      add_foreign_key :delivery_schedules, :products
    end

    # Add delivery_schedule_id to delivery_assignments if it doesn't exist
    unless column_exists?(:delivery_assignments, :delivery_schedule_id)
      add_column :delivery_assignments, :delivery_schedule_id, :bigint
      add_index :delivery_assignments, :delivery_schedule_id
      add_foreign_key :delivery_assignments, :delivery_schedules, if_not_exists: true
    end
  end

  def down
    if foreign_key_exists?(:delivery_assignments, :delivery_schedules)
      remove_foreign_key :delivery_assignments, :delivery_schedules
    end
    
    if column_exists?(:delivery_assignments, :delivery_schedule_id)
      remove_index :delivery_assignments, :delivery_schedule_id
      remove_column :delivery_assignments, :delivery_schedule_id
    end

    if foreign_key_exists?(:delivery_schedules, :products)
      remove_foreign_key :delivery_schedules, :products
    end
    
    if foreign_key_exists?(:delivery_schedules, :users)
      remove_foreign_key :delivery_schedules, :users
    end
    
    if foreign_key_exists?(:delivery_schedules, :customers)
      remove_foreign_key :delivery_schedules, :customers
    end
  end
end