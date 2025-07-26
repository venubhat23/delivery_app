class PurchaseInvoiceItem < ApplicationRecord
  belongs_to :purchase_invoice
  belongs_to :purchase_product
  
  validates :quantity, :price, presence: true, 
            numericality: { greater_than: 0 }
  validates :tax_rate, presence: true, 
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :discount, presence: true, 
            numericality: { greater_than_or_equal_to: 0 }
  
  before_save :calculate_amount
  before_save :set_hsn_sac
  after_create :update_product_stock
  after_destroy :revert_product_stock
  
  def calculate_amount
    base_amount = quantity * price
    discount_amount = base_amount * (discount / 100)
    self.amount = base_amount - discount_amount
  end
  
  def tax_amount
    amount * (tax_rate / 100)
  end
  
  def total_amount
    amount + tax_amount
  end
  
  def line_total
    (quantity * price) - discount + tax_amount
  end
  
  def product_name
    purchase_product&.name || 'Unknown Product'
  end
  

  
  def product_unit
    purchase_product&.measuring_unit || 'PCS'
  end
  
  private
  
  def set_hsn_sac
    self.hsn_sac = purchase_product&.hsn_sac if purchase_product&.hsn_sac.present?
  end
  
  def update_product_stock
    purchase_product.update_stock(quantity, 'add') if purchase_product
  end
  
  def revert_product_stock
    purchase_product.update_stock(quantity, 'subtract') if purchase_product
  end
end

