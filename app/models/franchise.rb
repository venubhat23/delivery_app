class Franchise < ApplicationRecord
  has_secure_password

  has_many :franchise_bookings, dependent: :destroy
  has_many :delivery_assignments, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true
  validates :location, presence: true

  scope :active, -> { where(active: true) }

  def total_bookings
    franchise_bookings.count
  end

  def total_bookings_amount
    franchise_bookings.sum(:price)
  end

  def pending_bookings
    franchise_bookings.where(status: 'pending')
  end

  def completed_bookings
    franchise_bookings.where(status: 'completed')
  end
end
