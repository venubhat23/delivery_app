# app/models/sales_product.rb
class SalesProduct < ApplicationRecord
  has_many :sales_invoice_items, dependent: :destroy
  has_many :sales_invoices, through: :sales_invoice_items

  validates :name, presence: true
  validates :category, presence: true
  validates :purchase_price, :sales_price, presence: true, numericality: { greater_than: 0 }
  validates :measuring_unit, presence: true
  validates :opening_stock, :current_stock, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :in_stock, -> { where('current_stock > 0') }
  scope :low_stock, -> { where('current_stock <= 10 AND current_stock > 0') }
  scope :out_of_stock, -> { where(current_stock: 0) }

  def self.categories
    distinct.pluck(:category).compact.sort
  end

  def profit_margin
    return 0 if purchase_price.nil? || purchase_price.zero?
    ((sales_price - purchase_price) / purchase_price * 100).round(2)
  end

  def stock_value
    current_stock * purchase_price
  end

  def stock_status
    case current_stock
    when 0
      'out_of_stock'
    when 1..10
      'low_stock'
    else
      'in_stock'
    end
  end

  def can_sell?(quantity)
    current_stock >= quantity
  end

  def reduce_stock!(quantity)
    if can_sell?(quantity)
      update!(current_stock: current_stock - quantity)
    else
      raise "Insufficient stock. Available: #{current_stock}, Required: #{quantity}"
    end
  end

  def display_name
    "#{name} (#{measuring_unit})"
  end

  def price_with_currency
    "₹#{sales_price}"
  end

  def stock_status_badge
    case stock_status
    when 'out_of_stock'
      'badge-danger'
    when 'low_stock'
      'badge-warning'
    else
      'badge-success'
    end
  end
end