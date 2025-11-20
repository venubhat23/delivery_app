class AddTypeToPayouts < ActiveRecord::Migration[8.0]
  def change
    add_column :payouts, :payout_type, :string, default: 'payment'
    add_index :payouts, :payout_type
  end
end
