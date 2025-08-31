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
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :final_amount_after_discount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :delivery_person_is_valid
  validate :discount_not_exceeding_total_amount

  # Callbacks
  before_save :calculate_and_set_final_amount

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
    return 0 unless product&.price && quantity
    (product.price.to_f * quantity.to_f).round(2)
  rescue => e
    Rails.logger.error "Error calculating total_amount for DeliveryAssignment #{id}: #{e.message}"
    0
  end

  def calculate_final_amount_after_discount
    base_amount = total_amount
    discount = discount_amount.to_f
    final_amount = [base_amount - discount, 0].max.round(2)
    
    # Update the stored value
    update_column(:final_amount_after_discount, final_amount) if final_amount_after_discount != final_amount
    
    final_amount
  end

  def final_amount
    return final_amount_after_discount if final_amount_after_discount.present?
    calculate_final_amount_after_discount
  end

  def discount_percentage
    return 0 if total_amount.zero? || discount_amount.to_f.zero?
    ((discount_amount.to_f / total_amount) * 100).round(2)
  end

  def has_discount?
    discount_amount.to_f > 0
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

  # Alias methods for backward compatibility
  def delivery_date
    scheduled_date
  end

  def delivery_date=(date)
    self.scheduled_date = date
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

  # Safe total calculation methods for analytics
  def self.safe_total_amount(deliveries)
    deliveries.sum do |delivery|
      delivery.total_amount || 0
    rescue => e
      Rails.logger.error "Error calculating amount for delivery #{delivery.id}: #{e.message}"
      0
    end
  end

  def self.safe_total_liters(deliveries)
    deliveries.joins(:product)
              .where(products: { unit_type: 'liters' })
              .sum(:quantity) || 0
  rescue => e
    Rails.logger.error "Error calculating total liters: #{e.message}"
    0
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

  def discount_not_exceeding_total_amount
    return unless discount_amount.present? && discount_amount > 0
    return unless product&.price && quantity
    
    total = total_amount
    if discount_amount > total
      errors.add(:discount_amount, "cannot exceed the total amount (Rs #{total.round(2)})")
    end
  end

  def calculate_and_set_final_amount
    # Only calculate if we have the necessary data
    return unless product&.price && quantity
    
    base_amount = total_amount
    discount = discount_amount.to_f
    
    # Calculate final amount after discount
    self.final_amount_after_discount = [base_amount - discount, 0].max.round(2)
  end
end
