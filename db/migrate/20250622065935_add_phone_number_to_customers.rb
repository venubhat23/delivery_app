class AddPhoneNumberToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :phone_number, :string
  end
end
