class AddPasswordToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :password_digest, :string
    add_column :customers, :email, :string
    add_index :customers, :email, unique: true
    add_index :customers, :phone_number, unique: true
  end
end