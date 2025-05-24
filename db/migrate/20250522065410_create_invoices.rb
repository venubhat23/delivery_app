class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      t.references :customer, null: false, foreign_key: true
      t.decimal :total_amount
      t.string :status
      t.date :invoice_date
      t.date :due_date

      t.timestamps
    end
  end
end
