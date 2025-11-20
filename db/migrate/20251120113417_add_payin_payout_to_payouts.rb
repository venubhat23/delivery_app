class AddPayinPayoutToPayouts < ActiveRecord::Migration[8.0]
  def change
    add_column :payouts, :payin_payout, :string, default: 'payout'
    add_index :payouts, :payin_payout
  end
end
