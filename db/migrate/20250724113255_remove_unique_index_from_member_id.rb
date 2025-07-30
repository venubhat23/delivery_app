class RemoveUniqueIndexFromMemberId < ActiveRecord::Migration[8.0]
  def change
    remove_index :customers, :member_id
  end
end
