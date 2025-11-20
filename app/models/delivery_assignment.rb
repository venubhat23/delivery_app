# app/models/delivery_assignment.rb
class DeliveryAssignment < ApplicationRecord
  belongs_to :customer, optional: true
  belongs_to :user, optional: true  # delivery person
  belongs_to :delivery_person, -> { where(role: 'delivery_person') }, class_name: 'User', foreign_key: 'user_id', optional: true
  belongs_to :product
  belongs_to :delivery_schedule, optional: true
  belongs_to :invoice, optional: true
  belongs_to :franchise, optional: true

  validates :customer_id, presence: true, unless: :belongs_to_quick_invoice?
  validates :product_id, :scheduled_date, :unit, presence: true
  validates :user_id, presence: true, unless: :allow_nil_user_id?
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending in_progress completed cancelled] }
  validates :unit, inclusion: { in: %w[liters gallons kg pounds pieces] }
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :final_amount_after_discount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :booked_by, presence: true, inclusion: { in: [0, 1, 2] }

  validate :delivery_person_is_valid
  validate :discount_not_exceeding_total_amount

  # Callbacks
  after_initialize :set_default_booked_by
  before_save :calculate_and_set_final_amount
  before_save :set_completed_at_if_completed
  after_update :award_points_for_completion, if: :status_changed_to_completed?

  # OPTIMIZED SCOPES with N+1 prevention
  scope :pending, -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :invoiced, -> { where(invoice_generated: true) }
  scope :not_invoiced, -> { where(invoice_generated: false) }
  scope :by_delivery_person, ->(user_id) { where(user_id: user_id) }
  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) if customer_id.present? }
  scope :for_date, ->(date) { where(scheduled_date: date) }
  scope :for_date_range, ->(start_date, end_date) { where(scheduled_date: start_date..end_date) }
  scope :scheduled, -> { where.not(delivery_schedule_id: nil) }
  scope :one_time, -> { where(delivery_schedule_id: nil) }
  scope :booked_by_customer, -> { where(booked_by: 1) }
  scope :booked_by_delivery_person, -> { where(booked_by: 2) }
  scope :booked_by_admin, -> { where(booked_by: 0) }
  scope :by_booked_by, ->(booked_by_value) { where(booked_by: booked_by_value) if booked_by_value.present? }
  scope :by_month, ->(month, year) {
    return all if month.blank? || year.blank?
    start_date = Date.new(year.to_i, month.to_i, 1).beginning_of_month
    end_date = start_date.end_of_month
    where(completed_at: start_date..end_date)
  }
  scope :search_by_customer, ->(term) { joins(:customer).where("customers.name ILIKE ?", "%#{term}%") }

  # N+1 Prevention Scopes
  scope :with_associations, -> { includes(:customer, :user, :product, :delivery_schedule, :invoice) }
  scope :with_basic_data, -> { includes(:customer, :user, :product) }
  scope :with_names, -> {
    select('delivery_assignments.*')
    .joins(:customer, :user, :product)
    .select('customers.name as customer_name, users.name as user_name, products.name as product_name')
  }

  # Performance optimized scopes for analytics
  scope :completed_with_amounts, -> {
    completed.joins(:product)
    .select('delivery_assignments.*, products.price')
  }

  scope :overdue, -> { pending.where('scheduled_date < ?', Date.current) }

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
    base_amount = total_amount.to_f || 0.0
    discount = discount_amount.to_f || 0.0
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

  def booked_by_display
    case booked_by
    when 1
      'Customer'
    when 2
      'Delivery Person'
    when 0
      'Admin'
    else
      'Unknown'
    end
  end

  def booked_by_customer?
    booked_by == 1
  end

  def booked_by_delivery_person?
    booked_by == 2
  end

  def booked_by_admin?
    booked_by == 0
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
      scheduled_date: start_date..end_date,
      invoice_generated: false
    ).includes(:product)
    summary = assignments.group_by(&:product).map do |product, product_assignments|
      total_quantity = product_assignments.sum(&:quantity)
      unit_price = product.price
      
      # Handle nil values properly using blocks
      total_discount = product_assignments.sum { |a| a.discount_amount.to_f }
      total_final_amount = product_assignments.sum { |a| a.final_amount_after_discount.to_f }
      
      {
        product: product,
        quantity: total_quantity,
        unit_price: product.price.to_f,
        discount: total_discount,
        total_amount: total_final_amount,
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

  def allow_nil_user_id?
    # Allow nil user_id for invoices created through sidebar
    invoice_generated? || status == 'completed'
  end

  private

  def set_default_booked_by
    # Only set default if booked_by attribute exists and is nil
    # This prevents errors when using select queries that don't include all columns
    if has_attribute?(:booked_by) && booked_by.nil?
      self.booked_by = 0
    end
  end

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

    base_amount = total_amount.to_f || 0.0
    discount = discount_amount.to_f || 0.0

    # Calculate final amount after discount
    final_amount = base_amount - discount
    self.final_amount_after_discount = [final_amount, 0].max.round(2)
  end

  def set_completed_at_if_completed
    # If status is being set to 'completed' and completed_at is not already set
    if status == 'completed' && completed_at.blank?
      # Set timezone to +0530 (IST)
      ist_time = Time.current.in_time_zone("Asia/Kolkata")
      self.completed_at = scheduled_date.present? ? scheduled_date.in_time_zone("Asia/Kolkata") : ist_time
    end
  end

  def status_changed_to_completed?
    status_changed? && status == 'completed' && status_was != 'completed'
  end

  def award_points_for_completion
    return unless customer && final_amount_after_discount.present?

    # Award 10 points for every ₹1000 spent
    amount = final_amount_after_discount.to_f
    points_to_award = (amount / 1000.0 * 10).floor

    if points_to_award > 0
      customer.award_points(
        points_to_award,
        'delivery',
        self,
        "Delivery completed for ₹#{amount.round(2)} - #{product_name}"
      )
    end
  rescue => e
    Rails.logger.error "Error awarding points for delivery assignment #{id}: #{e.message}"
  end

  private

  def belongs_to_quick_invoice?
    invoice&.is_quick_invoice?
  end
end
