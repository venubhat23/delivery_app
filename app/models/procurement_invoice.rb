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
    # Try to get completed assignments first, fall back to all assignments
    assignments = procurement_schedule.procurement_assignments.completed.includes(:product)
    assignments = procurement_schedule.procurement_assignments.includes(:product) if assignments.empty?

    invoice_items = assignments.map do |assignment|
      # Use actual data if available, otherwise use planned data
      quantity = assignment.actual_quantity.presence || assignment.planned_quantity || 0
      rate = assignment.buying_price.presence || assignment.planned_rate_per_unit || procurement_schedule.buying_price || 0
      amount = assignment.actual_cost.presence || (quantity * rate)

      {
        date: assignment.procurement_date&.strftime('%Y-%m-%d') || assignment.date&.strftime('%Y-%m-%d') || Date.current.strftime('%Y-%m-%d'),
        product_name: assignment.product&.name || procurement_schedule.product&.name || 'Milk',
        quantity: quantity,
        unit: assignment.unit || 'liters',
        rate: rate,
        amount: amount
      }
    end

    # If no assignments exist, create from schedule data
    if invoice_items.empty?
      # Generate daily items from schedule date range
      start_date = procurement_schedule.from_date || Date.current.beginning_of_month
      end_date = procurement_schedule.to_date || Date.current.end_of_month
      daily_quantity = (procurement_schedule.quantity || 0) / (end_date - start_date + 1).to_f
      daily_rate = procurement_schedule.buying_price || 0

      invoice_items = (start_date..end_date).map do |date|
        {
          date: date.strftime('%Y-%m-%d'),
          product_name: procurement_schedule.product&.name || 'Milk',
          quantity: daily_quantity.round(2),
          unit: 'liters',
          rate: daily_rate,
          amount: (daily_quantity * daily_rate).round(2)
        }
      end
    end

    total_quantity = invoice_items.sum { |item| item[:quantity] }
    total_amount = invoice_items.sum { |item| item[:amount] }

    {
      schedule_details: {
        id: procurement_schedule.id,
        from_date: procurement_schedule.from_date&.strftime('%Y-%m-%d') || Date.current.beginning_of_month.strftime('%Y-%m-%d'),
        to_date: procurement_schedule.to_date&.strftime('%Y-%m-%d') || Date.current.end_of_month.strftime('%Y-%m-%d'),
        planned_quantity: procurement_schedule.quantity || 0,
        buying_price: procurement_schedule.buying_price || 0,
        selling_price: procurement_schedule.selling_price || 0
      },
      invoice_items: invoice_items,
      totals: {
        total_quantity: total_quantity,
        total_amount: total_amount,
        item_count: invoice_items.count
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

    # Try completed assignments first, then fall back to planned data
    completed_assignments = procurement_schedule.procurement_assignments.completed
    if completed_assignments.any?
      self.total_amount = completed_assignments.sum(&:actual_cost)
    else
      # Calculate from planned data or schedule data
      assignments = procurement_schedule.procurement_assignments
      if assignments.any?
        self.total_amount = assignments.sum do |assignment|
          quantity = assignment.planned_quantity || 0
          rate = assignment.planned_rate_per_unit || procurement_schedule.buying_price || 0
          quantity * rate
        end
      else
        # Calculate from schedule data
        schedule_quantity = procurement_schedule.quantity || 0
        schedule_rate = procurement_schedule.buying_price || 0
        self.total_amount = schedule_quantity * schedule_rate
      end
    end
  end
  
  def set_invoice_date
    self.invoice_date = Date.current
  end
end
