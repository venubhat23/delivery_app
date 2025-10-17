class AddMonthAndYearToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :month, :integer
    add_column :invoices, :year, :integer

    # Set default values for existing invoices
    reversible do |dir|
      dir.up do
        # Update all existing invoices to have September 2025
        execute "UPDATE invoices SET month = 9, year = 2025 WHERE month IS NULL OR year IS NULL"
      end
    end

    # Add indexes for better performance on month/year queries
    add_index :invoices, [:month, :year]
    add_index :invoices, :year
  end
end
