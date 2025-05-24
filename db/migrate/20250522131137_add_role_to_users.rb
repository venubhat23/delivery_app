class AddRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, default: 'user' unless column_exists?(:users, :role)
    add_index :users, :role unless index_exists?(:users, :role)
  end
end
