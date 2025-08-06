# app/models/delivery_assignment.rb
class DeliveryAssignment < ApplicationRecord
  belongs_to :customer
  belongs_to :user  # delivery person
  belongs_to :delivery_person, -> { where(role: 'delivery_person') }, class_name: 'User', foreign_key: 'user_id'
  belongs_to :product
  belongs_to :delivery_schedule, optional: true
  belongs_to :invoice, optional: true

  validates :customer_id, :user_id, :product_id, :scheduled_date, :unit, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending in_progress completed cancelled] }

  validate :delivery_person_is_valid

  # SCOPES
  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :invoiced, -> { where(invoice_generated: true) }
  scope :not_invoiced, -> { where(invoice_generated: false) }
  scope :by_delivery_person, ->(user_id) { where(user_id: user_id) }
  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) if customer_id.present? }
  scope :for_date, ->(date) { where(scheduled_date: date) }
  scope :scheduled, -> { where.not(delivery_schedule_id: nil) }
  scope :one_time, -> { where(delivery_schedule_id: nil) }
  scope :by_month, ->(month, year) {
    return all if month.blank? || year.blank?
    start_date = Date.new(year.to_i, month.to_i, 1).beginning_of_month
    end_date = start_date.end_of_month
    where(completed_at: start_date..end_date)
  }
  scope :search_by_customer, ->(term) { joins(:customer).where("customers.name ILIKE ?", "%#{term}%") }

  # INSTANCE METHODS
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

  def total_amount
    (product&.price || 0) * (quantity || 0)
  end

  def status_display
    status.humanize
  end

  def status_badge_class
    case status
    when 'pending'
      'badge bg-warning text-dark'
    when 'in_progress'
      'badge bg-info text-white'
    when 'completed'
      'badge bg-success text-white'
    when 'cancelled'
      'badge bg-danger text-white'
    else
      'badge bg-secondary text-white'
    end
  end

  def pending?
    status == 'pending'
  end

  def overdue?
    pending? && scheduled_date < Date.current
  end

  def overdue_badge_class
    overdue? ? 'badge bg-danger text-white' : status_badge_class
  end

  def mark_as_completed!
    update!(status: 'completed', completed_at: Time.current)
  end

  def can_generate_invoice?
    status == 'completed' && !invoice_generated?
  end

  # Alias method for backward compatibility
  def delivery_date
    scheduled_date
  end

  # CLASS METHODS
  def self.monthly_summary_for_customer(customer_id, month, year)
    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    assignments = where(
      customer_id: customer_id,
      status: 'completed',
      completed_at: start_date..end_date,
      invoice_generated: false
    ).includes(:product)

    summary = assignments.group_by(&:product).map do |product, product_assignments|
      total_quantity = product_assignments.sum(&:quantity)
      unit_price = product.price
      total_amount = (total_quantity && unit_price) ? total_quantity * unit_price : 0

      {
        product: product,
        quantity: total_quantity,
        unit_price: unit_price,
        total_amount: total_amount,
        assignments_count: product_assignments.count
      }
    end

    {
      assignments: assignments,
      summary: summary,
      total_amount: summary.sum { |s| s[:total_amount] },
      month_year: start_date.strftime("%B %Y")
    }
  end

  private

  def delivery_date_not_in_past
    return unless scheduled_date.present? && scheduled_date < Date.current
    errors.add(:delivery_date, "cannot be in the past")
  end

  def delivery_person_is_valid
    return unless user.present? && !user.delivery_person?
    errors.add(:user, "must be a delivery person")
  end
end
