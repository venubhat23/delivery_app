class ProcurementAssignment < ApplicationRecord
  belongs_to :procurement_schedule
  belongs_to :user
  
  validates :vendor_name, presence: true, length: { maximum: 255 }
  validates :date, presence: true
  validates :planned_quantity, presence: true, numericality: { greater_than: 0 }
  validates :buying_price, presence: true, numericality: { greater_than: 0 }
  validates :selling_price, presence: true, numericality: { greater_than: 0 }
  validates :unit, presence: true, inclusion: { in: %w[liters gallons] }
  validates :status, inclusion: { in: %w[pending completed cancelled] }
  
  validates :actual_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  validate :actual_quantity_present_if_completed
  validate :completed_at_present_if_completed
  
  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :for_date, ->(date) { where(date: date) }
  scope :for_vendor, ->(vendor) { where(vendor_name: vendor) }
  scope :in_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :recent, -> { order(date: :desc) }
  
  before_update :set_completed_at_if_completed
  
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
  
  def quantity_variance
    return 0 unless actual_quantity
    actual_quantity - planned_quantity
  end
  
  def quantity_variance_percentage
    return 0 if planned_quantity.zero?
    ((quantity_variance / planned_quantity) * 100).round(2)
  end
  
  def profit_variance
    actual_profit - planned_profit
  end
  
  def overdue?
    status == 'pending' && date < Date.current
  end
  
  def today?
    date == Date.current
  end
  
  def future?
    date > Date.current
  end
  
  def mark_as_completed!(received_quantity, notes = nil)
    update!(
      actual_quantity: received_quantity,
      status: 'completed',
      completed_at: Time.current,
      notes: notes
    )
  end
  
  def mark_as_cancelled!(reason = nil)
    update!(
      status: 'cancelled',
      notes: reason
    )
  end
  
  # Class methods for analytics
  def self.total_planned_quantity_for_period(start_date, end_date)
    in_date_range(start_date, end_date).sum(:planned_quantity)
  end
  
  def self.total_actual_quantity_for_period(start_date, end_date)
    completed.in_date_range(start_date, end_date).sum(:actual_quantity)
  end
  
  def self.total_planned_cost_for_period(start_date, end_date)
    in_date_range(start_date, end_date).sum('planned_quantity * buying_price')
  end
  
  def self.total_actual_cost_for_period(start_date, end_date)
    completed.in_date_range(start_date, end_date).sum('actual_quantity * buying_price')
  end
  
  def self.total_actual_revenue_for_period(start_date, end_date)
    completed.in_date_range(start_date, end_date).sum('actual_quantity * selling_price')
  end
  
  def self.total_actual_profit_for_period(start_date, end_date)
    total_actual_revenue_for_period(start_date, end_date) - total_actual_cost_for_period(start_date, end_date)
  end
  
  def self.completion_rate_for_period(start_date, end_date)
    total_assignments = in_date_range(start_date, end_date).count
    return 0 if total_assignments.zero?
    completed_assignments = completed.in_date_range(start_date, end_date).count
    ((completed_assignments.to_f / total_assignments) * 100).round(2)
  end
  
  def self.vendors_summary_for_period(start_date, end_date)
    completed.in_date_range(start_date, end_date)
             .group(:vendor_name)
             .group('DATE(date)')
             .sum(:actual_quantity)
  end
  
  def self.daily_summary_for_period(start_date, end_date)
    completed.in_date_range(start_date, end_date)
             .group('DATE(date)')
             .select('DATE(date) as date, SUM(actual_quantity) as total_quantity, SUM(actual_quantity * buying_price) as total_cost, SUM(actual_quantity * selling_price) as total_revenue')
  end
  
  private
  
  def actual_quantity_present_if_completed
    if status == 'completed' && actual_quantity.blank?
      errors.add(:actual_quantity, 'must be present when status is completed')
    end
  end
  
  def completed_at_present_if_completed
    if status == 'completed' && completed_at.blank?
      errors.add(:completed_at, 'must be present when status is completed')
    end
  end
  
  def set_completed_at_if_completed
    if status == 'completed' && completed_at.blank?
      self.completed_at = Time.current
    end
  end
end