class PurchaseInvoiceItem < ApplicationRecord
  belongs_to :purchase_invoice
  belongs_to :purchase_product
  
  validates :quantity, :price, :amount, presence: true, 
            numericality: { greater_than: 0 }
  validates :tax_rate, presence: true, 
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :discount, presence: true, 
            numericality: { greater_than_or_equal_to: 0 }
  
  before_save :calculate_amount
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
  
  private
  
  def update_product_stock
    if purchase_invoice.purchase?
      purchase_product.update_stock(quantity, 'add')
    else
      purchase_product.update_stock(quantity, 'subtract')
    end
  end
  
  def revert_product_stock
    if purchase_invoice.purchase?
      purchase_product.update_stock(quantity, 'subtract')
    else
      purchase_product.update_stock(quantity, 'add')
    end
  end
end

