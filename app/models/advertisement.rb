class Advertisement < ApplicationRecord
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true, inclusion: { 
    in: %w[active inactive],
    message: "%{value} is not a valid status" 
  }
  
  # Custom validation for date range
  validate :end_date_after_start_date

  # Associations
  belongs_to :user

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :inactive, -> { where(status: 'inactive') }
  scope :current, -> { where('start_date <= ? AND end_date >= ?', Date.current, Date.current) }
  scope :upcoming, -> { where('start_date > ?', Date.current) }
  scope :expired, -> { where('end_date < ?', Date.current) }
  scope :by_user, ->(user) { where(user: user) }

  # Instance methods
  def active?
    status == 'active'
  end

  def inactive?
    status == 'inactive'
  end

  def current?
    Date.current.between?(start_date, end_date)
  end

  def upcoming?
    start_date > Date.current
  end

  def expired?
    end_date < Date.current
  end

  def status_class
    case status
    when 'active'
      if current?
        'success'
      elsif upcoming?
        'info'
      elsif expired?
        'secondary'
      else
        'success'
      end
    when 'inactive'
      'danger'
    else
      'secondary'
    end
  end

  def status_text
    case status
    when 'active'
      if current?
        'Active (Running)'
      elsif upcoming?
        'Active (Upcoming)'
      elsif expired?
        'Active (Expired)'
      else
        'Active'
      end
    when 'inactive'
      'Inactive'
    else
      status.humanize
    end
  end

  def display_name
    name
  end

  def duration_days
    (end_date - start_date).to_i + 1
  end

  # Class methods
  def self.status_options_for_select
    [
      ['Active', 'active'],
      ['Inactive', 'inactive']
    ]
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date

    if end_date < start_date
      errors.add(:end_date, 'must be after start date')
    end
  end
end