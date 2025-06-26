
# app/models/sales_invoice.rb
class SalesInvoice < ApplicationRecord
  has_many :sales_invoice_items, dependent: :destroy
  has_many :sales_products, through: :sales_invoice_items

  validates :invoice_number, presence: true, uniqueness: true
  validates :invoice_type, presence: true
  validates :customer_name, presence: true
  validates :invoice_date, presence: true
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  STATUSES = {
    draft: 'draft',
    pending: 'pending', 
    paid: 'paid',
    partially_paid: 'partially_paid',
    overdue: 'overdue',
    cancelled: 'cancelled'
  }.freeze

  INVOICE_TYPES = {
    sales: 'sales',
    service: 'service',
    mixed: 'mixed'
  }.freeze

  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_customer, ->(customer) { where('customer_name ILIKE ?', "%#{customer}%") if customer.present? }
  scope :by_date_range, ->(start_date, end_date) { where(invoice_date: start_date..end_date) if start_date.present? && end_date.present? }

  before_validation :generate_invoice_number, on: :create
  before_save :calculate_totals
  after_update :update_stock, if: :saved_change_to_status?

  def self.revenue_for_period(start_date, end_date)
    where(invoice_date: start_date..end_date, status: ['paid', 'partially_paid'])
      .sum(:amount_paid)
  end

  def self.profit_for_period(start_date, end_date)
    invoices = includes(sales_invoice_items: :sales_product)
               .where(invoice_date: start_date..end_date, status: ['paid', 'partially_paid'])
    
    total_profit = 0
    invoices.each do |invoice|
      invoice.sales_invoice_items.each do |item|
        cost = item.sales_product.purchase_price * item.quantity
        revenue = item.amount
        total_profit += (revenue - cost)
      end
    end
    total_profit
  end

  def outstanding_amount
    total_amount - amount_paid
  end

  def overdue?
    due_date.present? && due_date < Date.current && status != 'paid'
  end

  def mark_as_paid!
    update!(
      status: 'paid',
      amount_paid: total_amount,
      balance_amount: 0
    )
  end

  def add_payment(amount)
    new_amount_paid = amount_paid + amount
    new_status = if new_amount_paid >= total_amount
                   'paid'
                 elsif new_amount_paid > 0
                   'partially_paid'
                 else
                   'pending'
                 end

    update!(
      amount_paid: new_amount_paid,
      balance_amount: total_amount - new_amount_paid,
      status: new_status
    )
  end

  private

  def generate_invoice_number
    return if invoice_number.present?
    
    date_prefix = Date.current.strftime('%Y%m')
    last_invoice = SalesInvoice.where('invoice_number LIKE ?', "SI#{date_prefix}%")
                              .order(invoice_number: :desc)
                              .first
    
    if last_invoice
      last_number = last_invoice.invoice_number.split('-').last.to_i
      self.invoice_number = "SI#{date_prefix}-#{sprintf('%04d', last_number + 1)}"
    else
      self.invoice_number = "SI#{date_prefix}-0001"
    end
  end

  def calculate_totals
    self.subtotal = sales_invoice_items.sum { |item| item.quantity * item.price }
    self.tax_amount = sales_invoice_items.sum { |item| (item.quantity * item.price * item.tax_rate / 100) }
    self.discount_amount = sales_invoice_items.sum(&:discount)
    self.total_amount = subtotal + tax_amount - discount_amount
    self.balance_amount = total_amount - amount_paid
  end

  def update_stock
    if status == 'paid' && saved_change_to_status?[0] != 'paid'
      sales_invoice_items.each do |item|
        item.sales_product.reduce_stock!(item.quantity)
      end
    end
  end
end
