class ProcurementInvoice < ApplicationRecord
  belongs_to :user
  belongs_to :procurement_schedule
  
  validates :invoice_number, presence: true, uniqueness: true
  validates :invoice_date, presence: true
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :vendor_name, presence: true
  validates :status, inclusion: { in: %w[draft generated sent paid cancelled] }
  
  scope :draft, -> { where(status: 'draft') }
  scope :generated, -> { where(status: 'generated') }
  scope :sent, -> { where(status: 'sent') }
  scope :paid, -> { where(status: 'paid') }
  scope :for_vendor, ->(vendor) { where(vendor_name: vendor) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_invoice_date, -> { order(invoice_date: :desc) }
  
  before_validation :generate_invoice_number, on: :create
  before_validation :set_vendor_name, on: :create
  before_validation :calculate_total_amount, on: :create
  before_validation :set_invoice_date, on: :create
  
  def generate_invoice_data
    assignments = procurement_schedule.procurement_assignments.completed.includes(:product)
    
    invoice_items = assignments.map do |assignment|
      {
        date: assignment.date.strftime('%Y-%m-%d'),
        product_name: assignment.product&.name || 'N/A',
        quantity: assignment.actual_quantity,
        unit: assignment.unit,
        rate: assignment.buying_price,
        amount: assignment.actual_cost
      }
    end
    
    {
      schedule_details: {
        id: procurement_schedule.id,
        from_date: procurement_schedule.from_date.strftime('%Y-%m-%d'),
        to_date: procurement_schedule.to_date.strftime('%Y-%m-%d'),
        planned_quantity: procurement_schedule.quantity,
        buying_price: procurement_schedule.buying_price,
        selling_price: procurement_schedule.selling_price
      },
      invoice_items: invoice_items,
      totals: {
        total_quantity: assignments.sum(&:actual_quantity),
        total_amount: assignments.sum(&:actual_cost),
        item_count: assignments.count
      }
    }
  end
  
  def is_generated?
    status == 'generated'
  end
  
  def is_draft?
    status == 'draft'
  end
  
  def can_be_regenerated?
    %w[draft generated].include?(status)
  end
  
  def mark_as_generated!
    update!(status: 'generated', invoice_data: generate_invoice_data.to_json)
  end
  
  def mark_as_sent!
    update!(status: 'sent')
  end
  
  def mark_as_paid!
    update!(status: 'paid')
  end
  
  def parsed_invoice_data
    return {} if invoice_data.blank?
    JSON.parse(invoice_data).with_indifferent_access
  rescue JSON::ParserError
    {}
  end
  
  def invoice_items
    parsed_invoice_data.dig(:invoice_items) || []
  end
  
  def schedule_details
    parsed_invoice_data.dig(:schedule_details) || {}
  end
  
  def invoice_totals
    parsed_invoice_data.dig(:totals) || {}
  end
  
  private
  
  def generate_invoice_number
    return if invoice_number.present?
    
    date_prefix = Date.current.strftime('%Y%m')
    last_invoice = ProcurementInvoice.where('invoice_number LIKE ?', "PI#{date_prefix}%")
                                   .order(:invoice_number)
                                   .last
    
    if last_invoice
      sequence = last_invoice.invoice_number.match(/PI\d{6}(\d{4})$/)[1].to_i + 1
    else
      sequence = 1
    end
    
    self.invoice_number = "PI#{date_prefix}#{sequence.to_s.rjust(4, '0')}"
  end
  
  def set_vendor_name
    self.vendor_name = procurement_schedule.vendor_name if procurement_schedule
  end
  
  def calculate_total_amount
    return unless procurement_schedule
    
    completed_assignments = procurement_schedule.procurement_assignments.completed
    self.total_amount = completed_assignments.sum(&:actual_cost)
  end
  
  def set_invoice_date
    self.invoice_date = Date.current
  end
end
