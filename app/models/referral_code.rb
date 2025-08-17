class ReferralCode < ApplicationRecord
  belongs_to :customer

  validates :code, presence: true, uniqueness: true, length: { in: 6..20 }
  validates :total_credits, numericality: { greater_than_or_equal_to: 0 }
  validates :total_referrals, numericality: { greater_than_or_equal_to: 0 }
  validates :share_url_slug, uniqueness: true, allow_blank: true

  before_validation :generate_code, if: -> { code.blank? }
  before_validation :generate_share_url_slug, if: -> { share_url_slug.blank? }

  scope :active, -> { joins(:customer).where(customers: { is_active: true }) }
  scope :with_referrals, -> { where('total_referrals > 0') }
  scope :with_credits, -> { where('total_credits > 0') }
  scope :recent, -> { order(created_at: :desc) }

  def generate_share_url
    Rails.application.routes.url_helpers.referral_url(share_url_slug) if share_url_slug.present?
  end

  def add_referral!(credits = 10)
    increment!(:total_referrals)
    increment!(:total_credits, credits)
  end

  def use_credits!(amount)
    return false if total_credits < amount
    
    decrement!(:total_credits, amount)
    true
  end

  def has_credits?
    total_credits > 0
  end

  def has_referrals?
    total_referrals > 0
  end

  def self.find_by_code_or_slug(identifier)
    where(code: identifier).or(where(share_url_slug: identifier)).first
  end

  def self.generate_unique_code
    loop do
      code = SecureRandom.alphanumeric(8).upcase
      break code unless exists?(code: code)
    end
  end

  def self.leaderboard(limit = 10)
    active.order(total_referrals: :desc).limit(limit)
  end

  def self.total_referrals_count
    sum(:total_referrals)
  end

  def self.total_credits_distributed
    sum(:total_credits)
  end

  private

  def generate_code
    self.code = self.class.generate_unique_code
  end

  def generate_share_url_slug
    self.share_url_slug = SecureRandom.urlsafe_base64(12)
  end
end