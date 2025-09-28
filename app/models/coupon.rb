class Coupon < ApplicationRecord
  # Validations
  validates :code, presence: true, uniqueness: true, length: { minimum: 6, maximum: 20 }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, length: { maximum: 500 }
  validates :status, presence: true, inclusion: { in: %w[active inactive expired] }
  validates :expires_at, presence: true

  # Callbacks
  before_validation :generate_coupon_code, on: :create, if: -> { code.blank? }
  before_validation :set_default_expiration, on: :create, if: -> { expires_at.blank? }
  before_validation :set_default_status, on: :create, if: -> { status.blank? }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :inactive, -> { where(status: 'inactive') }
  scope :expired, -> { where(status: 'expired') }
  scope :valid_coupons, -> { where(status: 'active').where('expires_at > ?', Time.current) }
  scope :expiring_soon, -> { where('expires_at BETWEEN ? AND ?', Time.current, 7.days.from_now) }

  # Instance methods
  def expired?
    expires_at < Time.current || status == 'expired'
  end

  def active_and_valid?
    status == 'active' && expires_at > Time.current
  end

  def expiring_soon?
    expires_at.between?(Time.current, 7.days.from_now)
  end

  def days_until_expiry
    return 0 if expired?
    ((expires_at - Time.current) / 1.day).ceil
  end

  def status_class
    case status
    when 'active'
      expired? ? 'danger' : 'success'
    when 'inactive'
      'warning'
    when 'expired'
      'danger'
    else
      'secondary'
    end
  end

  def formatted_amount
    "₹#{amount.to_f.round(2)}"
  end

  def display_name
    "#{code} - #{formatted_amount}"
  end

  # Class methods
  def self.total_value
    sum(:amount)
  end

  def self.generate_unique_code
    loop do
      code = "COUP#{SecureRandom.alphanumeric(6).upcase}"
      break code unless exists?(code: code)
    end
  end

  def self.cleanup_expired
    where('expires_at < ?', Time.current).update_all(status: 'expired')
  end

  private

  def generate_coupon_code
    self.code = self.class.generate_unique_code
  end

  def set_default_expiration
    self.expires_at = 3.months.from_now
  end

  def set_default_status
    self.status = 'active'
  end
end
