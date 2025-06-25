class PurchaseInvoice < ApplicationRecord
  has_many :purchase_invoice_items, dependent: :destroy
  has_many :purchase_products, through: :purchase_invoice_items
  
  validates :invoice_number, presence: true, uniqueness: true
  validates :invoice_type, presence: true, inclusion: { in: %w[purchase sales] }
  validates :party_name, :invoice_date, presence: true
  validates :payment_terms, presence: true, numericality: { greater_than: 0 }
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  before_validation :generate_invoice_number, on: :create
  before_validation :set_due_date
  after_update :update_payment_status
  
  scope :purchases, -> { where(invoice_type: 'purchase') }
  scope :sales, -> { where(invoice_type: 'sales') }
  scope :paid, -> { where(status: 'paid') }
  scope :unpaid, -> { where(status: 'unpaid') }
  scope :overdue, -> { where('due_date < ? AND status != ?', Date.current, 'paid') }
  
  def calculate_totals
    self.subtotal = purchase_invoice_items.sum(&:amount)
    self.tax_amount = purchase_invoice_items.sum { |item| item.amount * item.tax_rate / 100 }
    self.total_amount = subtotal + tax_amount - discount_amount
    self.balance_amount = total_amount - amount_paid
  end
  
  def mark_as_paid!
    update!(
      amount_paid: total_amount,
      balance_amount: 0,
      status: 'paid'
    )
  end
  
  def purchase?
    invoice_type == 'purchase'
  end
  
  def sales?
    invoice_type == 'sales'
  end
  
  def overdue?
    due_date < Date.current && status != 'paid'
  end
  
  def profit_amount
    return 0 unless sales?
    
    total_profit = 0
    purchase_invoice_items.includes(:purchase_product).each do |item|
      cost = item.purchase_product.purchase_price * item.quantity
      total_profit += (item.amount - cost)
    end
    total_profit
  end
  
  private
  
  def generate_invoice_number
    return if invoice_number.present?
    
    prefix = invoice_type == 'purchase' ? 'PUR' : 'SAL'
    last_invoice = PurchaseInvoice.where(invoice_type: invoice_type)
                                 .where('invoice_number LIKE ?', "#{prefix}%")
                                 .order(:invoice_number)
                                 .last
    
    if last_invoice
      last_number = last_invoice.invoice_number.gsub(prefix, '').to_i
      self.invoice_number = "#{prefix}#{(last_number + 1).to_s.rjust(4, '0')}"
    else
      self.invoice_number = "#{prefix}0001"
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
  end
end
