class ProcurementAssignment < ApplicationRecord
  belongs_to :procurement_schedule
  belongs_to :user

  validates :vendor_name, :date, presence: true
  validates :planned_quantity, :buying_price, :selling_price, presence: true, numericality: { greater_than: 0 }
  validates :actual_quantity, numericality: { greater_than: 0 }, allow_nil: true
  validates :status, presence: true, inclusion: { in: %w[pending completed cancelled] }
  validates :unit, presence: true

  scope :pending, -> { where(status: 'pending') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :by_vendor, ->(vendor_name) { where(vendor_name: vendor_name) }
  scope :by_date, ->(date) { where(date: date) }
  scope :by_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :by_month, ->(month, year) {
    return all if month.blank? || year.blank?
    start_date = Date.new(year.to_i, month.to_i, 1).beginning_of_month
    end_date = start_date.end_of_month
    where(date: start_date..end_date)
  }

  def quantity_to_use
    actual_quantity.present? ? actual_quantity : planned_quantity
  end

  def total_cost
    quantity_to_use * buying_price
  end

  def expected_revenue
    quantity_to_use * selling_price
  end

  def profit
    expected_revenue - total_cost
  end

  def profit_margin_percentage
    return 0 if total_cost.zero?
    ((profit / total_cost) * 100).round(2)
  end

  def variance
    return 0 unless actual_quantity.present?
    actual_quantity - planned_quantity
  end

  def variance_percentage
    return 0 if planned_quantity.zero? || actual_quantity.blank?
    ((variance / planned_quantity) * 100).round(2)
  end

  def status_badge_class
    case status
    when 'pending'
      'badge bg-warning text-dark'
    when 'completed'
      'badge bg-success text-white'
    when 'cancelled'
      'badge bg-danger text-white'
    else
      'badge bg-secondary text-white'
    end
  end

  def overdue?
    pending? && date < Date.current
  end

  def pending?
    status == 'pending'
  end

  def completed?
    status == 'completed'
  end

  def mark_as_completed!(actual_qty = nil)
    self.actual_quantity = actual_qty if actual_qty.present?
    self.status = 'completed'
    self.completed_at = Time.current
    save!
  end

  def cancel!
    update!(status: 'cancelled')
  end

  # Class methods for analytics
  def self.total_milk_received(start_date = nil, end_date = nil)
    scope = completed
    scope = scope.by_date_range(start_date, end_date) if start_date && end_date
    scope.sum(:actual_quantity)
  end

  def self.total_cost(start_date = nil, end_date = nil)
    scope = completed
    scope = scope.by_date_range(start_date, end_date) if start_date && end_date
    scope.sum('actual_quantity * buying_price')
  end

  def self.expected_revenue(start_date = nil, end_date = nil)
    scope = completed
    scope = scope.by_date_range(start_date, end_date) if start_date && end_date
    scope.sum('actual_quantity * selling_price')
  end

  def self.vendor_summary(start_date = nil, end_date = nil)
    scope = completed
    scope = scope.by_date_range(start_date, end_date) if start_date && end_date
    
    scope.group(:vendor_name).group('DATE(date)').sum(:actual_quantity)
  end

  def self.monthly_summary(month, year)
    by_month(month, year).completed.group(:vendor_name).sum(:actual_quantity)
  end
end