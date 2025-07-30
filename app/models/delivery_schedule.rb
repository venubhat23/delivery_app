class DeliverySchedule < ApplicationRecord
  belongs_to :customer
  belongs_to :user, foreign_key: 'user_id' # delivery person
  belongs_to :product, optional: true
  has_many :delivery_assignments, dependent: :destroy

  # Attribute to track if this is being created during bulk import
  attr_accessor :skip_past_date_validation

  validates :frequency, presence: true, inclusion: { in: %w[daily weekly bi_weekly monthly] }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[active inactive completed cancelled] }
  validates :default_quantity, presence: true, numericality: { greater_than: 0 }
  
  validate :end_date_after_start_date
  validate :start_date_not_in_past

  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
  scope :by_delivery_person, ->(user_id) { where(user_id: user_id) }

  def delivery_person
    user
  end

  def delivery_person_name
    user&.name
  end

  def customer_name
    customer&.name
  end

  def product_name
    product&.name
  end

  def duration_in_days
    return 0 unless start_date && end_date
    (end_date - start_date).to_i + 1
  end

  def estimated_delivery_count
    return 0 unless start_date && end_date && frequency
    
    current_date = start_date
    count = 0
    
    while current_date <= end_date
      count += 1
      current_date = next_delivery_date(current_date)
    end
    
    count
  end

  def next_delivery_date(current_date)
    case frequency
    when 'daily'
      current_date + 1.day
    when 'weekly'
      current_date + 1.week
    when 'bi_weekly'
      current_date + 2.weeks
    when 'monthly'
      current_date + 1.month
    else
      current_date + 1.day
    end
  end

  def frequency_display
    case frequency
    when 'daily'
      'Daily'
    when 'weekly'
      'Weekly'
    when 'bi_weekly'
      'Bi-Weekly'
    when 'monthly'
      'Monthly'
    else
      frequency&.titleize
    end
  end

  def status_badge_class
    case status
    when 'active'
      'bg-success'
    when 'inactive'
      'bg-secondary'
    when 'completed'
      'bg-primary'
    when 'cancelled'
      'bg-danger'
    else
      'bg-secondary'
    end
  end

  def can_be_activated?
    %w[inactive cancelled].include?(status) && start_date >= Date.current
  end

  def can_be_cancelled?
    status == 'active'
  end

  def complete!
    update!(status: 'completed')
  end

  def cancel!
    update!(status: 'cancelled')
    # Optionally cancel pending delivery assignments
    delivery_assignments.where(status: 'pending').update_all(status: 'cancelled')
  end

  def activate!
    return false unless can_be_activated?
    update!(status: 'active')
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date < start_date
      errors.add(:end_date, 'must be after start date')
    end
  end

  def start_date_not_in_past
    return unless start_date
    return if skip_past_date_validation
    
    if start_date < Date.current
      errors.add(:start_date, 'cannot be in the past')
    end
  end
end