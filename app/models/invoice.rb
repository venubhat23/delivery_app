# app/models/invoice.rb
require 'securerandom'

class Invoice < ApplicationRecord
  belongs_to :customer
  has_many :invoice_items, dependent: :destroy
  has_many :products, through: :invoice_items
  has_many :delivery_assignments, dependent: :nullify
  
  accepts_nested_attributes_for :invoice_items, allow_destroy: true, reject_if: :all_blank
  
  # Validations
  validates :customer_id, presence: true
  validates :invoice_date, presence: true
  validates :due_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending paid overdue] }
  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :invoice_number, presence: true, uniqueness: true
  
  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :paid, -> { where(status: 'paid') }
  scope :overdue, -> { where(status: 'overdue') }
  scope :overdue_invoices, -> { where('due_date < ? AND status != ?', Date.current, 'paid') }
  scope :due_for_reminder, -> { where('due_date = ? AND status = ?', Date.current + 3.days, 'pending') }
  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) if customer_id.present? }
  scope :by_month, ->(month, year) {
    return all if month.blank? || year.blank?
    start_date = Date.new(year.to_i, month.to_i, 1).beginning_of_month
    end_date = start_date.end_of_month
    where(invoice_date: start_date..end_date)
  }
  scope :by_date_range, ->(from_date, to_date) { 
    scope = all
    scope = scope.where('invoice_date >= ?', from_date) if from_date.present?
    scope = scope.where('invoice_date <= ?', to_date) if to_date.present?
    scope
  }
  scope :search_by_number_or_customer, ->(query) {
    return all if query.blank?
    joins(:customer).where(
      "invoices.invoice_number ILIKE ? OR customers.name ILIKE ?", 
      "%#{query}%", "%#{query}%"
    )
  }
  
  # Callbacks
  before_create :generate_invoice_number, if: -> { invoice_number.blank? }
  before_create :generate_share_token
  before_save :calculate_total_amount
  after_create :mark_delivery_assignments_as_invoiced
  
  # Instance methods
  def formatted_number
    invoice_number
  end
  
  def mark_as_paid!
    update!(status: 'paid', paid_at: Time.current)
  end
  
  def mark_as_overdue!
    update!(status: 'overdue')
  end
  
  def send_reminder!
    # Logic to send reminder email/SMS
    InvoiceReminderJob.perform_later(self) if defined?(InvoiceReminderJob)
    update!(last_reminder_sent_at: Time.current)
  end
  
  def overdue?
    due_date < Date.current && status != 'paid'
  end
  
  def days_overdue
    return 0 unless overdue?
    (Date.current - due_date).to_i
  end

  def generate_share_token
    self.share_token = SecureRandom.urlsafe_base64(32) if share_token.blank?
  end

  def mark_as_shared!
    update!(shared_at: Time.current)
  end

  def public_url(host: nil, port: nil)
    url_options = { token: share_token }
    
    

      url_options[:host] = "http://gnu-modern-totally.ngrok-free.app"
    
    
    Rails.application.routes.url_helpers.public_invoice_url(url_options)
  end

  def public_pdf_url(host: nil, port: nil)
    url_options = { token: share_token }
    
    # Ensure we always have a host
    
    Rails.application.routes.url_helpers.public_invoice_download_url(url_options)
  end
  
  def profit_amount
    return 0 unless invoice_type == 'profit_invoice'
    invoice_items.sum { |item| (item.unit_price - (item.product&.cost_price || 0)) * item.quantity }
  end
  
  def is_profit_invoice?
    invoice_type == 'profit_invoice'
  end
  
  def is_sales_invoice?
    invoice_type == 'sales_invoice'
  end
  def month_year
    invoice_date.strftime("%B %Y")
  end
  
  # Class methods
def self.generate_invoice_number(type = 'manual')
    prefix = case type
             when 'profit_invoice'
               'PROF'
             when 'sales_invoice'
               'SALE'
             else
               'INV'
             end
    
    last_invoice = Invoice.where("invoice_number LIKE ?", "#{prefix}-%").order(:created_at).last
    if last_invoice&.invoice_number
      last_number = last_invoice.invoice_number.gsub(/\D/, '').to_i
      "#{prefix}-#{(last_number + 1).to_s.rjust(6, '0')}"
    else
      "#{prefix}-000001"
    end
  end
  
  def self.invoice_stats
    {
      pending: pending.count,
      paid: paid.count,
      overdue: overdue.count,
      total_pending_amount: pending.sum(:total_amount),
      total_paid_amount: paid.sum(:total_amount)
    }
  end
  
  def self.generate_invoice_for_customer_month(customer_id, month, year)
    customer = Customer.find(customer_id)
    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month
    
    # Check if invoice already exists
    # existing_invoice = Invoice.where(
    #   customer: customer,
    #   invoice_date: start_date..end_date,
    #   invoice_type: 'monthly'
    # ).first
    
    # return { success: false, message: "Invoice already exists for this month" } if existing_invoice
    
    # Get completed delivery assignments for this customer in the month
    assignments = DeliveryAssignment.where(
      customer: customer,
      status: 'completed',
      completed_at: start_date..end_date,
      invoice_generated: false
    ).includes(:product)
    
    return { success: false, message: "No completed deliveries found for this month" } if assignments.empty?
    
    invoice = create_invoice_from_assignments(customer, assignments, start_date)
    
    if invoice
      { success: true, invoice: invoice, message: "Invoice generated successfully" }
    else
      { success: false, message: "Failed to generate invoice" }
    end
  end

  def self.generate_monthly_invoices_for_all_customers(month = Date.current.month, year = Date.current.year)
    results = []
    customers_with_deliveries = Customer.joins(:delivery_assignments)
                                      .where(delivery_assignments: { 
                                        status: 'completed',
                                        completed_at: Date.new(year, month, 1).beginning_of_month..Date.new(year, month, 1).end_of_month,
                                        invoice_generated: false
                                      })
                                      .distinct
    
    customers_with_deliveries.each do |customer|
      result = generate_invoice_for_customer_month(customer.id, month, year)
      results << {
        customer: customer,
        result: result
      }
    end
    
    results
  end

 def generate_invoice_number
    self.invoice_number = self.class.generate_invoice_number(invoice_type)
  end
  
  def calculate_total_amount
    # Calculate base amount (excluding tax)
    taxable_amount = invoice_items.sum { |item| item.quantity * (item.unit_price || 0) }
    
    # Calculate total tax
    total_tax = invoice_items.sum do |item|
      base_amount = item.quantity * (item.unit_price || 0)
      item.product&.total_tax_amount_for(base_amount) || 0
    end
    
    self.total_amount = taxable_amount + total_tax
  end
  
  def mark_delivery_assignments_as_invoiced
    delivery_assignments.update_all(invoice_generated: true, invoice_id: id)
  end
  def self.create_invoice_from_assignments(customer, assignments, invoice_date)
    return nil if assignments.empty?

    invoice = Invoice.new(
      customer: customer,
      invoice_date: invoice_date,
      due_date: invoice_date + 10.days,
      status: 'pending',
      invoice_type: 'monthly'
    )

    total_amount = 0

    grouped_assignments = assignments.group_by(&:product_id)

    grouped_assignments.each do |product_id, product_assignments|
      product = Product.find(product_id)
      total_quantity = product_assignments.sum(&:quantity)
      unit_price = product.price
      total_price = (total_quantity && unit_price) ? total_quantity * unit_price : 0

      invoice.invoice_items.build(
        product: product,
        quantity: total_quantity,
        unit_price: unit_price,
        total_price: total_price
      )

      total_amount += total_price
    end

    # Set required fields
    invoice.total_amount = invoice.invoice_items.sum(&:total_price)

    invoice.invoice_number = generate_invoice_number  # You’ll need to define this method
    if invoice.save
      invoice.update!(total_amount: total_amount)

      assignments.update_all(invoice_generated: true, invoice_id: invoice.id)
      invoice
    else
      Rails.logger.error "Failed to create invoice for customer #{customer.id}: #{invoice.errors.full_messages}"
      nil
    end
  end

  
  private
  
  def generate_invoice_number
    self.invoice_number = self.class.generate_invoice_number
  end
  
  def calculate_total_amount
    # Calculate base amount (excluding tax)
    taxable_amount = invoice_items.sum { |item| item.quantity * (item.unit_price || 0) }
    
    # Calculate total tax
    total_tax = invoice_items.sum do |item|
      base_amount = item.quantity * (item.unit_price || 0)
      item.product&.total_tax_amount_for(base_amount) || 0
    end
    
    self.total_amount = taxable_amount + total_tax
  end
  
  def mark_delivery_assignments_as_invoiced
    delivery_assignments.update_all(invoice_generated: true, invoice_id: id)
  end
end