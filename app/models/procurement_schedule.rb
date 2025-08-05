class ProcurementSchedule < ApplicationRecord
  belongs_to :user
  has_many :procurement_assignments, dependent: :destroy
  
  validates :vendor_name, presence: true, length: { maximum: 255 }
  validates :from_date, presence: true
  validates :to_date, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :buying_price, presence: true, numericality: { greater_than: 0 }
  validates :selling_price, presence: true, numericality: { greater_than: 0 }
  validates :unit, presence: true, inclusion: { in: %w[liters gallons] }
  validates :status, inclusion: { in: %w[active inactive completed cancelled] }
  
  validate :to_date_after_from_date
  
  scope :active, -> { where(status: 'active') }
  scope :by_vendor, ->(vendor) { where(vendor_name: vendor) }
  scope :in_date_range, ->(start_date, end_date) { where('from_date <= ? AND to_date >= ?', end_date, start_date) }
  
  after_create :generate_daily_assignments
  after_update :update_assignments_if_needed
  
  def total_planned_quantity
    (from_date..to_date).count * quantity
  end
  
  def total_planned_cost
    total_planned_quantity * buying_price
  end
  
  def total_expected_revenue
    total_planned_quantity * selling_price
  end
  
  def expected_profit
    total_expected_revenue - total_planned_cost
  end
  
  def profit_margin_percentage
    return 0 if total_planned_cost.zero?
    ((expected_profit / total_planned_cost) * 100).round(2)
  end
  
  def actual_total_quantity
    procurement_assignments.sum(:actual_quantity)
  end
  
  def actual_total_cost
    procurement_assignments.sum { |assignment| (assignment.actual_quantity || 0) * assignment.buying_price }
  end
  
  def completion_percentage
    total_assignments = procurement_assignments.count
    return 0 if total_assignments.zero?
    completed_assignments = procurement_assignments.where(status: 'completed').count
    ((completed_assignments.to_f / total_assignments) * 100).round(2)
  end
  
  def days_count
    (to_date - from_date).to_i + 1
  end
  
  def self.total_quantity_for_period(start_date, end_date)
    joins(:procurement_assignments)
      .where(procurement_assignments: { date: start_date..end_date, status: 'completed' })
      .sum('procurement_assignments.actual_quantity')
  end
  
  def self.total_cost_for_period(start_date, end_date)
    joins(:procurement_assignments)
      .where(procurement_assignments: { date: start_date..end_date, status: 'completed' })
      .sum('procurement_assignments.actual_quantity * procurement_assignments.buying_price')
  end
  
  private
  
  def to_date_after_from_date
    return unless from_date && to_date
    
    if to_date < from_date
      errors.add(:to_date, 'must be after or equal to from date')
    end
  end
  
  def generate_daily_assignments
    return unless from_date && to_date
    
    (from_date..to_date).each do |date|
      procurement_assignments.create!(
        vendor_name: vendor_name,
        date: date,
        planned_quantity: quantity,
        buying_price: buying_price,
        selling_price: selling_price,
        unit: unit,
        user: user,
        status: 'pending'
      )
    end
  end
  
  def update_assignments_if_needed
    # Update existing assignments if key fields changed
    if saved_change_to_quantity? || saved_change_to_buying_price? || saved_change_to_selling_price?
      procurement_assignments.where(status: 'pending').update_all(
        planned_quantity: quantity,
        buying_price: buying_price,
        selling_price: selling_price
      )
    end
  end
end