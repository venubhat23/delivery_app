
# app/models/sales_invoice_item.rb
class SalesInvoiceItem < ApplicationRecord
  belongs_to :sales_invoice
  belongs_to :sales_product, optional: true
  belongs_to :product, optional: true

  validates :quantity, :price, presence: true, numericality: { greater_than: 0 }
  validates :tax_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :item_type, inclusion: { in: %w[Product SalesProduct] }
  
  validate :item_presence

  before_save :calculate_amount
  before_save :set_hsn_sac

  def tax_amount
    (quantity * price * tax_rate / 100).round(2)
  end

  def line_total
    (quantity * price).round(2)
  end

  def subtotal
    line_total - discount
  end

  def total_with_tax
    subtotal + tax_amount
  end

  def get_product
    item_type == 'Product' ? product : sales_product
  end

  def product_name
    get_product&.name || 'Unknown Product'
  end

  def product_price
    case item_type
    when 'Product'
      product&.price
    when 'SalesProduct'
      sales_product&.sales_price
    end
  end

  def profit_amount
    return 0 unless get_product&.respond_to?(:purchase_price) && get_product.purchase_price
    
    cost = get_product.purchase_price * quantity
    revenue = amount
    revenue - cost
  end

  def profit_margin_percentage
    return 0 unless get_product&.respond_to?(:purchase_price) && get_product.purchase_price
    
    cost = get_product.purchase_price * quantity
    return 0 if cost.zero?
    
    ((amount - cost) / cost * 100).round(2)
  end

  private

  def item_presence
    if item_type == 'Product' && product.nil?
      errors.add(:product, 'must be present when item type is Product')
    elsif item_type == 'SalesProduct' && sales_product.nil?
      errors.add(:sales_product, 'must be present when item type is SalesProduct')
    end
  end

  def calculate_amount
    line_total = quantity * price
    tax_amt = line_total * tax_rate / 100
    self.amount = line_total + tax_amt - discount
  end

  def set_hsn_sac
    case item_type
    when 'Product'
      # Products don't have HSN/SAC in the current structure, but we can add it later
      self.hsn_sac = product&.hsn_sac if product&.respond_to?(:hsn_sac) && product&.hsn_sac.present?
    when 'SalesProduct'
      self.hsn_sac = sales_product&.hsn_sac if sales_product&.hsn_sac.present?
    end
  end
end
