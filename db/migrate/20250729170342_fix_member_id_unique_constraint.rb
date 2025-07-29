class FixMemberIdUniqueConstraint < ActiveRecord::Migration[8.0]
  def up
    # First, check if the unique index still exists and remove it
    if index_exists?(:customers, :member_id, unique: true)
      remove_index :customers, :member_id
    end
    
    # Clean up any existing empty string member_ids by setting them to nil
    # This prevents unique constraint violations with empty strings
    execute "UPDATE customers SET member_id = NULL WHERE member_id = ''"
    
    # Add a partial unique index that only applies to non-null member_ids
    # This allows multiple customers with null member_ids but ensures unique non-null values
    add_index :customers, :member_id, unique: true, where: "member_id IS NOT NULL"
  end
  
  def down
    # Remove the partial unique index
    remove_index :customers, :member_id if index_exists?(:customers, :member_id)
    
    # Add back the original unique index (this might fail if there are duplicates)
    add_index :customers, :member_id, unique: true
  end
end
