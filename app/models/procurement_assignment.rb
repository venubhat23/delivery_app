class ProcurementAssignment < ApplicationRecord
  belongs_to :procurement_schedule
  belongs_to :user
  belongs_to :product, optional: true

  validates :vendor_name, presence: true
  validates :date, presence: true, uniqueness: { scope: [:procurement_schedule_id, :vendor_name], on: :create }
  validates :planned_quantity, :buying_price, :selling_price, presence: true, numericality: { greater_than: 0 }
  validates :actual_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status, inclusion: { in: %w[pending completed cancelled] }
  validates :unit, presence: true

  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :for_date, ->(date) { where(date: date) }
  scope :for_vendor, ->(vendor) { where(vendor_name: vendor) }
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :with_actual_quantity, -> { where.not(actual_quantity: nil) }
  scope :recent, -> { order(date: :desc) }
  scope :by_date, -> { order(:date) }

  before_update :set_completed_at
  before_update :update_status_based_on_actual_quantity

  def planned_cost
    planned_quantity * buying_price
  end

  def planned_revenue
    planned_quantity * selling_price
  end

  def planned_profit
    planned_revenue - planned_cost
  end

  def actual_cost
    return 0 unless actual_quantity
    actual_quantity * buying_price
  end

  def actual_revenue
    return 0 unless actual_quantity
    actual_quantity * selling_price
  end

  def actual_profit
    actual_revenue - actual_cost
  end

  def variance_quantity
    return 0 unless actual_quantity
    actual_quantity - planned_quantity
  end

  def variance_percentage
    return 0 if planned_quantity.zero? || actual_quantity.nil?
    ((actual_quantity - planned_quantity) / planned_quantity * 100).round(2)
  end

  def profit_margin_percentage
    return 0 if buying_price.zero?
    ((selling_price - buying_price) / buying_price * 100).round(2)
  end

  def is_completed?
    status == 'completed' && actual_quantity.present?
  end

  def is_overdue?
    date < Date.current && status == 'pending'
  end

  def can_be_edited?
    # Allow editing of pending and completed assignments
    # Remove date restriction to allow editing past assignments
    %w[pending completed].include?(status)
  end

  def mark_as_completed!(actual_qty = nil)
    update!(
      status: 'completed',
      actual_quantity: actual_qty || actual_quantity,
      completed_at: Time.current
    )
  end

  def mark_as_cancelled!
    update!(status: 'cancelled', completed_at: Time.current)
  end

  def formatted_date
    date.strftime('%B %d, %Y')
  end

  def day_of_week
    date.strftime('%A')
  end

  # Class methods for analytics
  def self.total_planned_quantity_for_period(start_date, end_date)
    for_date_range(start_date, end_date).sum(:planned_quantity)
  end

  def self.total_actual_quantity_for_period(start_date, end_date)
    for_date_range(start_date, end_date).sum(:actual_quantity)
  end

  def self.total_planned_cost_for_period(start_date, end_date)
    for_date_range(start_date, end_date).sum('planned_quantity * buying_price')
  end

  def self.total_actual_cost_for_period(start_date, end_date)
    with_actual_quantity.for_date_range(start_date, end_date).sum('actual_quantity * buying_price')
  end

  def self.total_planned_revenue_for_period(start_date, end_date)
    for_date_range(start_date, end_date).sum('planned_quantity * selling_price')
  end

  def self.total_actual_revenue_for_period(start_date, end_date)
    with_actual_quantity.for_date_range(start_date, end_date).sum('actual_quantity * selling_price')
  end

  def self.profit_for_period(start_date, end_date)
    total_actual_revenue_for_period(start_date, end_date) - total_actual_cost_for_period(start_date, end_date)
  end

  def self.completion_rate_for_period(start_date, end_date)
    total_assignments = for_date_range(start_date, end_date).count
    return 0 if total_assignments.zero?
    
    completed_assignments = for_date_range(start_date, end_date).completed.count
    (completed_assignments.to_f / total_assignments * 100).round(2)
  end

  private

  def set_completed_at
    if actual_quantity_changed? && actual_quantity.present? && completed_at.nil?
      self.completed_at = Time.current
    end
  end

  def update_status_based_on_actual_quantity
    if actual_quantity.present? && status == 'pending'
      self.status = 'completed'
    end
  end
end