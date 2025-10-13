class PendingPayment < ApplicationRecord
  belongs_to :customer
  belongs_to :user

  validates :month, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending paid] }
  validates :customer_id, uniqueness: { scope: [:month, :year], message: "already has a pending payment for this month" }

  scope :pending, -> { where(status: 'pending') }
  scope :paid, -> { where(status: 'paid') }
  scope :for_month, ->(month, year) { where(month: month, year: year) }
  scope :by_customer, ->(customer) { where(customer: customer) }

  def self.total_pending_amount
    pending.sum(:amount)
  end

  def self.total_paid_amount
    paid.sum(:amount)
  end

  def month_year_display
    "#{month}/#{year}"
  end

  def mark_as_paid!
    update!(status: 'paid', paid_at: Time.current)
  end

  def mark_as_pending!
    update!(status: 'pending', paid_at: nil)
  end

  def paid?
    status == 'paid'
  end

  def pending?
    status == 'pending'
  end
end