class FranchiseBooking < ApplicationRecord
  belongs_to :franchise
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :booking_date, presence: true
  validates :status, presence: true

  enum :status, {
    pending: 'pending',
    confirmed: 'confirmed',
    completed: 'completed',
    cancelled: 'cancelled'
  }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_date_range, ->(start_date, end_date) { where(booking_date: start_date..end_date) }

  before_validation :calculate_price, if: :quantity_changed?

  def total_amount
    quantity * price
  end

  def formatted_total_amount
    "₹#{total_amount.to_f}"
  end

  private

  def calculate_price
    return unless product.present? && quantity.present?

    self.price = product.price
  end
end
