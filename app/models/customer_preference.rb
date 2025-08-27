class CustomerPreference < ApplicationRecord
  belongs_to :customer

  validates :language, inclusion: { in: %w[en hi te ta kn ml] }
  validates :delivery_time_start, presence: true
  validates :delivery_time_end, presence: true
  validate :end_time_after_start_time

  serialize :notification_preferences, JSON

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

  private

  def end_time_after_start_time
    return unless delivery_time_start && delivery_time_end
    
    if delivery_time_end <= delivery_time_start
      errors.add(:delivery_time_end, "must be after start time")
    end
  end
end
