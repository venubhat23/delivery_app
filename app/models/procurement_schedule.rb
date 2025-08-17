class ProcurementSchedule < ApplicationRecord
  belongs_to :user
  has_many :procurement_assignments, dependent: :destroy

  validates :vendor_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :from_date, :to_date, presence: true
  validates :quantity, :buying_price, :selling_price, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: %w[active inactive completed cancelled] }
  validates :unit, presence: true, inclusion: { in: %w[liters gallons kg pounds pieces] }
  
  validate :to_date_after_from_date

  scope :active, -> { where(status: 'active') }
  scope :by_vendor, ->(vendor) { where(vendor_name: vendor) }
  scope :by_date_range, ->(start_date, end_date) { where(from_date: start_date..end_date) }
  scope :recent, -> { order(created_at: :desc) }

  after_create :generate_procurement_assignments
  after_update :regenerate_assignments_if_needed

  def duration_in_days
    (to_date - from_date).to_i + 1
  end

  def total_planned_quantity
    duration_in_days * quantity
  end

  def total_planned_cost
    total_planned_quantity * buying_price
  end

  def total_planned_revenue
    total_planned_quantity * selling_price
  end

  def planned_profit
    total_planned_revenue - total_planned_cost
  end

  def actual_total_quantity
    procurement_assignments.sum(:actual_quantity)
  end

  def actual_total_cost
    procurement_assignments.where.not(actual_quantity: nil).sum('actual_quantity * buying_price')
  end

  def actual_total_revenue
    procurement_assignments.where.not(actual_quantity: nil).sum('actual_quantity * selling_price')
  end

  def actual_profit
    actual_total_revenue - actual_total_cost
  end

  def completion_percentage
    return 0 if procurement_assignments.empty?
    
    completed_assignments = procurement_assignments.where.not(actual_quantity: nil).count
    (completed_assignments.to_f / procurement_assignments.count * 100).round(2)
  end

  def profit_margin_percentage
    return 0 if buying_price.zero?
    
    ((selling_price - buying_price) / buying_price * 100).round(2)
  end

  def can_be_edited?
    %w[active inactive].include?(status)
  end

  def mark_as_completed!
    update!(status: 'completed', updated_at: Time.current)
  end

  def mark_as_cancelled!
    update!(status: 'cancelled', updated_at: Time.current)
  end

  private

  def to_date_after_from_date
    return unless from_date && to_date
    
    if to_date < from_date
      errors.add(:to_date, 'must be after from date')
    end
  end


  def generate_procurement_assignments
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

  def regenerate_assignments_if_needed
    if saved_change_to_from_date? || saved_change_to_to_date? || 
       saved_change_to_quantity? || saved_change_to_buying_price? || 
       saved_change_to_selling_price?
      
      # Delete existing assignments and regenerate
      procurement_assignments.destroy_all
      generate_procurement_assignments
    end
  end
end