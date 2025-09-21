class UserVacation < ApplicationRecord
  belongs_to :customer
  belongs_to :created_by_user, class_name: 'User', foreign_key: 'created_by', optional: true

  STATUSES = %w[active paused cancelled completed].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :start_date, :end_date, presence: true
  validates :end_date, comparison: { greater_than_or_equal_to: :start_date }
  
  validate :no_overlapping_active_vacations, on: :create
  validate :date_range_not_too_long
  validate :start_date_not_in_past, on: :create

  after_create :skip_assignments_if_active
  before_save :complete_if_ended

  scope :active, -> { where(status: 'active') }
  scope :paused, -> { where(status: 'paused') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :completed, -> { where(status: 'completed') }
  scope :for_customer, ->(customer_id) { where(customer_id: customer_id) }
  scope :overlapping_with, ->(start_date, end_date) { 
    where("start_date <= ? AND end_date >= ?", end_date, start_date) 
  }
  scope :active_or_paused, -> { where(status: ['active', 'paused']) }
  scope :ended, -> { where('end_date < ?', Date.current) }

  def self.complete_ended_vacations
    ended_vacations = active.ended.or(paused.ended)
    
    ended_vacations.find_each do |vacation|
      vacation.transaction do
        vacation.update!(status: 'completed')
        vacation.send(:reinstate_assignments)
      end
    end
    
    ended_vacations.count
  end

  def as_json(options = {})
    super(options.merge(
      except: [:created_at, :updated_at, :created_by],
      methods: [:affected_assignments_count]
    ))
  end

  def date_range
    start_date..end_date
  end

  def active?
    status == 'active'
  end

  def paused?
    status == 'paused'
  end

  def cancelled?
    status == 'cancelled'
  end

  def completed?
    status == 'completed'
  end

  def can_be_paused?
    active? && start_date >= Date.current
  end

  def can_be_unpaused?
    paused? && start_date >= Date.current
  end

  def can_be_cancelled?
    (active? || paused?) && start_date >= Date.current
  end

  def pause!
    return false unless can_be_paused?
    
    transaction do
      update!(status: 'paused', paused_at: Time.current, unpaused_at: nil)
      reinstate_assignments
    end
  end

  def unpause!
    return false unless can_be_unpaused?
    
    transaction do
      update!(status: 'active', unpaused_at: Time.current)
      skip_assignments
    end
  end

  def cancel!
    return false unless can_be_cancelled?
    
    transaction do
      update!(status: 'cancelled', cancelled_at: Time.current)
      reinstate_assignments
    end
  end

  def affected_assignments_count
    return 0 unless customer
    
    customer.delivery_assignments
           .where(scheduled_date: date_range)
           .where(status: ['scheduled', 'skipped_vacation', 'pending'])
           .count
  end

  private

  def no_overlapping_active_vacations
    return unless customer && start_date && end_date

    overlapping = customer.user_vacations
                         .active_or_paused
                         .overlapping_with(start_date, end_date)
                         .where.not(id: id)

    if overlapping.exists?
      errors.add(:base, "Vacation dates overlap with an existing active or paused vacation")
    end
  end

  def date_range_not_too_long
    return unless start_date && end_date

    if (end_date - start_date) > VacationConfig::MAX_VACATION_DURATION
      max_days = VacationConfig::MAX_VACATION_DURATION.to_i / 1.day
      errors.add(:end_date, "Vacation cannot be longer than #{max_days} days")
    end
  end

  def start_date_not_in_past
    return unless start_date

    if start_date < Date.current
      errors.add(:start_date, "Cannot create vacation for past dates")
    end
  end

  def skip_assignments
    return unless customer

    affected_assignments = customer.delivery_assignments
                                  .where(scheduled_date: future_dates_in_range)
                                  .where(status: ['scheduled', 'pending'])

    # Store original status before changing to skipped_vacation
    affected_assignments.find_each do |assignment|
      # Store original status in cancellation_reason for restoration
      original_status = assignment.status
      assignment.update!(
        status: 'skipped_vacation',
        cancellation_reason: "VACATION:#{original_status}:#{start_date}:#{end_date}"
      )
    end

    affected_assignments.count
  end

  def reinstate_assignments
    return unless customer

    skipped_assignments = customer.delivery_assignments
                                 .where(scheduled_date: future_dates_in_range)
                                 .where(status: 'skipped_vacation')
                                 .where('cancellation_reason LIKE ?', 'VACATION:%')

    # Restore original status from cancellation_reason
    skipped_assignments.find_each do |assignment|
      if assignment.cancellation_reason&.start_with?('VACATION:')
        parts = assignment.cancellation_reason.split(':')
        original_status = parts[1] || 'scheduled'
        assignment.update!(
          status: original_status,
          cancellation_reason: nil
        )
      else
        assignment.update!(
          status: 'scheduled',
          cancellation_reason: nil
        )
      end
    end

    recreate_missing_assignments

    skipped_assignments.count
  end

  def future_dates_in_range
    timezone = VacationConfig::DEFAULT_TIMEZONE
    effective_start = VacationConfig.effective_start_date(start_date, timezone)
    effective_start..end_date
  end

  def recreate_missing_assignments
    return unless customer

    customer.delivery_schedules.active.each do |schedule|
      dates_in_vacation = future_dates_in_range.select do |date|
        schedule_matches_date?(schedule, date)
      end

      dates_in_vacation.each do |date|
        existing = customer.delivery_assignments.find_by(
          scheduled_date: date,
          product_id: schedule.product_id
        )

        unless existing
          customer.delivery_assignments.create!(
            delivery_schedule: schedule,
            user: schedule.user,
            product: schedule.product,
            scheduled_date: date,
            quantity: schedule.default_quantity,
            unit: schedule.default_unit,
            status: 'scheduled'
          )
        end
      end
    end
  end

  def schedule_matches_date?(schedule, date)
    case schedule.frequency
    when 'daily'
      true
    when 'weekly'
      date.wday == schedule.start_date.wday
    when 'monthly'
      date.day == schedule.start_date.day
    else
      false
    end
  end

  def skip_assignments_if_active
    skip_assignments if status == 'active'
  end

  def complete_if_ended
    if (active? || paused?) && end_date < Date.current
      self.status = 'completed'
    end
  end
end