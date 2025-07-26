class PurchaseInvoice < ApplicationRecord
  belongs_to :purchase_customer, foreign_key: 'party_name', primary_key: 'name', optional: true
  has_many :purchase_invoice_items, dependent: :destroy
  has_many :purchase_products, through: :purchase_invoice_items
  
  accepts_nested_attributes_for :purchase_invoice_items, allow_destroy: true, reject_if: :all_blank
  
  validates :invoice_number, presence: true, uniqueness: true
  validates :party_name, :invoice_date, presence: true
  validates :payment_terms, presence: true, numericality: { greater_than: 0 }
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  STATUSES = {
    draft: 'draft',
    unpaid: 'unpaid',
    paid: 'paid',
    partial: 'partial',
    overdue: 'overdue',
    cancelled: 'cancelled'
  }.freeze
  
  PAYMENT_TYPES = {
    cash: 'cash',
    bank: 'bank',
    upi: 'upi',
    card: 'card',
    cheque: 'cheque'
  }.freeze
  
  before_validation :generate_invoice_number, on: :create
  before_validation :set_due_date
  before_save :calculate_totals
  after_update :update_payment_status
  
  scope :paid, -> { where(status: 'paid') }
  scope :unpaid, -> { where(status: 'unpaid') }
  scope :partial, -> { where(status: 'partial') }
  scope :overdue, -> { where('due_date < ? AND status NOT IN (?)', Date.current, ['paid', 'cancelled']) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_party, ->(party) { where('party_name ILIKE ?', "%#{party}%") if party.present? }
  scope :by_date_range, ->(start_date, end_date) { where(invoice_date: start_date..end_date) if start_date.present? && end_date.present? }
  scope :recent, -> { order(created_at: :desc) }
  
  def self.total_purchases
    sum(:total_amount)
  end
  
  def self.total_paid
    sum(:amount_paid)
  end
  
  def self.total_unpaid
    sum(:balance_amount)
  end
  
  def self.summary_stats
    {
      total_purchases: total_purchases,
      total_paid: total_paid,
      total_unpaid: total_unpaid,
      overdue_count: overdue.count
    }
  end
  
  def calculate_totals
    self.subtotal = purchase_invoice_items.sum { |item| 
      (item.quantity && item.price) ? item.quantity * item.price : 0 
    }
    self.tax_amount = purchase_invoice_items.sum { |item| 
      (item.quantity && item.price && item.tax_rate) ? (item.quantity * item.price * item.tax_rate / 100) : 0 
    }
    self.discount_amount = purchase_invoice_items.sum(&:discount) + (additional_discount || 0)
    
    # Add additional charges
    charges = additional_charges || 0
    
    # Calculate total before rounding
    calculated_total = subtotal + tax_amount - discount_amount + charges
    
    # Auto round off if enabled
    if auto_round_off?
      self.round_off_amount = calculated_total.round - calculated_total
      calculated_total = calculated_total.round
    end
    
    self.total_amount = calculated_total
    self.balance_amount = total_amount - amount_paid
  end
  
  def mark_as_paid!(payment_type = 'cash')
    transaction do
      # First update the amount_paid, which will trigger calculate_totals
      self.amount_paid = total_amount
      self.status = 'paid'
      self.payment_type = payment_type
      save!
    end
  end
  
  def add_payment(amount, payment_type = 'cash')
    new_amount_paid = amount_paid + amount
    new_status = if new_amount_paid >= total_amount
                   'paid'
                 elsif new_amount_paid > 0
                   'partial'
                 else
                   'unpaid'
                 end

    update!(
      amount_paid: new_amount_paid,
      balance_amount: total_amount - new_amount_paid,
      status: new_status,
      payment_type: payment_type
    )
  end
  
  def overdue?
    due_date < Date.current && status != 'paid'
  end
  
  def days_until_due
    return 0 if due_date.nil? || overdue?
    (due_date - Date.current).to_i
  end
  
  def days_overdue
    return 0 unless overdue?
    (Date.current - due_date).to_i
  end
  
  def status_badge_class
    case status
    when 'paid'
      'badge-success'
    when 'partial'
      'badge-warning'
    when 'overdue'
      'badge-danger'
    when 'cancelled'
      'badge-secondary'
    else
      'badge-primary'
    end
  end
  
  def party_address
    purchase_customer&.full_address || ''
  end
  
  def party_phone
    purchase_customer&.phone_number || ''
  end
  
  def party_email
    purchase_customer&.email || ''
  end
  
  def party_gst
    purchase_customer&.gst_number || ''
  end
  
  def shipping_address
    purchase_customer&.shipping_address_display || party_address
  end
  
  private
  
  def generate_invoice_number
    return if invoice_number.present?
    
    date_prefix = Date.current.strftime('%Y%m')
    last_invoice = PurchaseInvoice.where('invoice_number LIKE ?', "PI#{date_prefix}%")
                                 .order(invoice_number: :desc)
                                 .first
    
    if last_invoice
      last_number = last_invoice.invoice_number.split('-').last.to_i
      self.invoice_number = "PI#{date_prefix}-#{sprintf('%04d', last_number + 1)}"
    else
      self.invoice_number = "PI#{date_prefix}-0001"
    end
  end
  
  def set_due_date
    self.due_date = invoice_date + payment_terms.days if invoice_date && payment_terms
  end
  
  def update_payment_status
    if amount_paid >= total_amount
      self.status = 'paid'
      self.balance_amount = 0
    elsif amount_paid > 0
      self.status = 'partial'
      self.balance_amount = total_amount - amount_paid
    else
      self.status = 'unpaid'
      self.balance_amount = total_amount
    end
    
    # Check if overdue
    if overdue? && status != 'paid'
      self.status = 'overdue'
    end
  end
end
