class Payout < ApplicationRecord
  validates :name, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :date, presence: true
  validates :paid_via, presence: true
  validates :payout_type, presence: true
  validates :payin_payout, presence: true
  validates :transaction_id, presence: true, unless: :cash?

  enum :paid_via, {
    cash: 'Cash',
    upi: 'UPI',
    net_banking: 'NetBanking',
    credit_card: 'CreditCard',
    debit_card: 'DebitCard',
    cheque: 'Cheque',
    neft: 'NEFT',
    rtgs: 'RTGS'
  }

  enum :payout_type, {
    payment: 'payment',
    receipt: 'receipt'
  }

  enum :payin_payout, {
    payin: 'payin',
    payout: 'payout'
  }

  scope :cash_payments, -> { where(paid_via: :cash) }
  scope :non_cash_payments, -> { where.not(paid_via: :cash) }
  scope :payments, -> { where(payout_type: :payment) }
  scope :receipts, -> { where(payout_type: :receipt) }
  scope :payins, -> { where(payin_payout: :payin) }
  scope :payouts, -> { where(payin_payout: :payout) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_type, ->(type) { where(payout_type: type) if type.present? }
  scope :by_payin_payout, ->(type) { where(payin_payout: type) if type.present? }

  def formatted_amount
    "₹#{amount.to_f}"
  end

  def payment_method_display
    case paid_via
    when 'net_banking'
      'Net Banking'
    when 'credit_card'
      'Credit Card'
    when 'debit_card'
      'Debit Card'
    else
      paid_via.humanize
    end
  end

  def type_display
    payout_type.humanize
  end

  def type_icon
    case payout_type
    when 'payment'
      'fa-arrow-up text-danger'
    when 'receipt'
      'fa-arrow-down text-success'
    else
      'fa-exchange-alt text-info'
    end
  end

  def payin_payout_display
    payin_payout.humanize
  end

  def payin_payout_color
    case payin_payout
    when 'payin'
      'text-success'
    when 'payout'
      'text-danger'
    else
      'text-muted'
    end
  end

  def payin_payout_badge_color
    case payin_payout
    when 'payin'
      'bg-success'
    when 'payout'
      'bg-danger'
    else
      'bg-secondary'
    end
  end
end