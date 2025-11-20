class Affiliate < ApplicationRecord
  has_secure_password

  has_many :referrals, dependent: :destroy
  has_many :affiliate_bookings, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true
  validates :location, presence: true
  validates :commission_rate, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :total_earnings, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_create :generate_referral_code
  before_create :set_defaults

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  enum :status, { pending: 0, approved: 1, rejected: 2, suspended: 3 }

  def total_referrals
    referrals.count
  end

  def approved_referrals
    referrals.where(status: 'approved').count
  end

  def pending_referrals
    referrals.where(status: 'pending').count
  end

  def calculate_earnings
    referrals.where(status: 'approved').sum(:reward_amount)
  end

  def update_total_earnings!
    update(total_earnings: calculate_earnings)
  end

  private

  def generate_referral_code
    self.referral_code = "AFF#{SecureRandom.alphanumeric(8).upcase}"
  end

  def set_defaults
    self.active = true if active.nil?
    self.status = 'pending' if status.blank?
    self.total_earnings = 0.0 if total_earnings.nil?
  end

  # Also add an after_initialize callback to set defaults for existing records
  after_initialize :set_defaults_for_existing

  def set_defaults_for_existing
    self.status = 'pending' if status.blank?
    self.total_earnings = 0.0 if total_earnings.nil?
  end
end
