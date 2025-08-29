class CustomerPreference < ApplicationRecord
  belongs_to :customer

  validates :language, inclusion: { in: %w[en hi te ta kn ml] }
  validates :delivery_time_start, presence: true
  validates :delivery_time_end, presence: true
  validates :referral_code, uniqueness: true, allow_blank: true
  validate :end_time_after_start_time

  serialize :notification_preferences, coder: JSON

  before_create :generate_referral_code_if_enabled

  scope :by_language, ->(lang) { where(language: lang) }
  scope :with_time_window, -> { where.not(delivery_time_start: nil, delivery_time_end: nil) }

  def delivery_time_window
    return nil unless delivery_time_start && delivery_time_end
    "#{delivery_time_start.strftime('%I:%M %p')} - #{delivery_time_end.strftime('%I:%M %p')}"
  end

  def notification_settings
    notification_preferences || {}
  end

  def update_notification_preference(key, value)
    prefs = notification_settings
    prefs[key.to_s] = value
    update(notification_preferences: prefs)
  end

  def prefers_notification?(type)
    notification_settings[type.to_s] == true
  end

  def generate_referral_code
    return if referral_code.present?
    
    loop do
      code = "REF#{customer.id}#{SecureRandom.alphanumeric(4).upcase}"
      if CustomerPreference.where(referral_code: code).empty?
        self.referral_code = code
        break
      end
    end
  end

  def add_referral_earnings(amount)
    return unless referral_enabled?
    
    self.referral_earnings = (referral_earnings || 0) + amount
    save
  end

  def formatted_referral_earnings
    "₹#{referral_earnings&.to_f || 0}"
  end

  def language_display_name
    case language
    when 'en' then 'English'
    when 'hi' then 'Hindi'
    when 'te' then 'Telugu'
    when 'ta' then 'Tamil'
    when 'kn' then 'Kannada'
    when 'ml' then 'Malayalam'
    else 'English'
    end
  end

  private

  def generate_referral_code_if_enabled
    generate_referral_code if referral_enabled?
  end

  def end_time_after_start_time
    return unless delivery_time_start && delivery_time_end
    
    if delivery_time_end <= delivery_time_start
      errors.add(:delivery_time_end, "must be after start time")
    end
  end
end
