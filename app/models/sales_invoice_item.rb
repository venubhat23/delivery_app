
# app/models/sales_invoice_item.rb
class SalesInvoiceItem < ApplicationRecord
  belongs_to :sales_invoice
  belongs_to :sales_product

  validates :quantity, :price, presence: true, numericality: { greater_than: 0 }
  validates :tax_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount, presence: true, numericality: { greater_than_or_equal_to: 0 }

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

  def profit_amount
    return 0 unless sales_product&.purchase_price
    
    cost = sales_product.purchase_price * quantity
    revenue = amount
    revenue - cost
  end

  def profit_margin_percentage
    return 0 unless sales_product&.purchase_price
    
    cost = sales_product.purchase_price * quantity
    return 0 if cost.zero?
    
    ((amount - cost) / cost * 100).round(2)
  end

  private

  def calculate_amount
    line_total = quantity * price
    tax_amt = line_total * tax_rate / 100
    self.amount = line_total + tax_amt - discount
  end

  def set_hsn_sac
    self.hsn_sac = sales_product&.hsn_sac if sales_product&.hsn_sac.present?
  end
end
