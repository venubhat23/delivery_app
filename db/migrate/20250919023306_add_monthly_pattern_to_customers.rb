class AddMonthlyPatternToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :monthly_pattern, :string, default: 'irregular'
    add_column :customers, :pattern_updated_at, :datetime
    add_index :customers, :monthly_pattern
  end
end
