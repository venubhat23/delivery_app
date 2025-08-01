# app/models/invoice_item.rb
class InvoiceItem < ApplicationRecord
  belongs_to :invoice
  belongs_to :product
  
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than: 0 }
  validates :total_price, presence: true, numericality: { greater_than: 0 }
  
  before_save :calculate_total_price
  
  # Helper methods for tax calculations
  def base_amount
    quantity * unit_price
  end
  
  def tax_amount
    product&.total_tax_amount_for(base_amount) || 0
  end
  
  def amount_with_tax
    base_amount + tax_amount
  end
  
  def cgst_amount
    product&.cgst_amount_for(base_amount) || 0
  end
  
  def sgst_amount
    product&.sgst_amount_for(base_amount) || 0
  end
  
  def igst_amount
    product&.igst_amount_for(base_amount) || 0
  end
  
  private
  
  def calculate_total_price
    # Store base amount (excluding tax) in total_price
    # This matches the AMOUNT column in the invoice format
    self.total_price = quantity * unit_price if quantity && unit_price
  end
end