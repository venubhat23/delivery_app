class AffiliateBooking < ApplicationRecord
  belongs_to :affiliate
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :booking_date, presence: true
  validates :status, presence: true

  enum :status, { pending: 0, confirmed: 1, completed: 2, cancelled: 3 }

  scope :recent, -> { order(created_at: :desc) }
  scope :this_month, -> { where(booking_date: Date.current.beginning_of_month..Date.current.end_of_month) }
  scope :last_month, -> { where(booking_date: Date.current.last_month.beginning_of_month..Date.current.last_month.end_of_month) }

  before_create :set_defaults

  def total_amount
    quantity * price
  end

  def can_be_cancelled?
    pending? || confirmed?
  end

  def confirm!
    update!(status: 'confirmed')
  end

  def complete!
    update!(status: 'completed')
  end

  def cancel!(reason = nil)
    self.notes = reason if reason.present?
    update!(status: 'cancelled')
  end

  private

  def set_defaults
    self.booking_date = Date.current if booking_date.nil?
    self.status = 'pending' if status.blank?
  end
end
