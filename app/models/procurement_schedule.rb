class ProcurementSchedule < ApplicationRecord
  belongs_to :user
  has_many :procurement_assignments, dependent: :destroy

  validates :vendor_name, presence: true
  validates :from_date, :to_date, presence: true
  validates :quantity, :buying_price, :selling_price, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[active inactive completed cancelled] }
  validates :unit, presence: true

  validate :end_date_after_start_date

  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :by_vendor, ->(vendor_name) { where(vendor_name: vendor_name) }
  scope :by_date_range, ->(start_date, end_date) { where(from_date: start_date..end_date) }

  def duration_in_days
    return 0 unless from_date && to_date
    (to_date - from_date).to_i + 1
  end

  def total_planned_amount
    quantity * buying_price
  end

  def expected_revenue
    quantity * selling_price
  end

  def expected_profit
    expected_revenue - total_planned_amount
  end

  def profit_margin_percentage
    return 0 if total_planned_amount.zero?
    ((expected_profit / total_planned_amount) * 100).round(2)
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

  def can_be_cancelled?
    status == 'active'
  end

  def can_generate_assignments?
    status == 'active' && from_date <= Date.current && to_date >= Date.current
  end

  def generate_assignments!
    return false unless can_generate_assignments?

    current_date = from_date
    daily_quantity = quantity / duration_in_days

    while current_date <= to_date
      procurement_assignments.find_or_create_by(date: current_date) do |assignment|
        assignment.vendor_name = vendor_name
        assignment.planned_quantity = daily_quantity
        assignment.buying_price = buying_price
        assignment.selling_price = selling_price
        assignment.unit = unit
        assignment.user = user
        assignment.status = 'pending'
      end
      current_date += 1.day
    end

    true
  end

  def complete!
    update!(status: 'completed')
  end

  def cancel!
    update!(status: 'cancelled')
    procurement_assignments.where(status: 'pending').update_all(status: 'cancelled')
  end

  private

  def end_date_after_start_date
    return unless from_date && to_date

    if to_date < from_date
      errors.add(:to_date, 'must be after from date')
    end
  end
end