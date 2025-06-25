class AddPhoneNumberToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :phone_number, :string
  end
end
