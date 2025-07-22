class PurchaseProduct < ApplicationRecord
  has_many :purchase_invoice_items, dependent: :destroy
  has_many :purchase_invoices, through: :purchase_invoice_items
  
  validates :name, presence: true, uniqueness: true
  validates :category, presence: true
  validates :purchase_price, :sales_price, presence: true, 
            numericality: { greater_than: 0 }
  validates :measuring_unit, presence: true
  validates :opening_stock, :current_stock, presence: true, 
            numericality: { greater_than_or_equal_to: 0 }
  
  scope :with_stock, -> { where('current_stock > 0') }
  scope :low_stock, ->(threshold = 10) { where('current_stock <= ?', threshold) }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  
  def profit_margin
    return 0 if purchase_price.zero?
    ((sales_price - purchase_price) / purchase_price * 100).round(2)
  end
  
  def profit_amount
    sales_price - purchase_price
  end
  
  def stock_value
    current_stock * purchase_price
  end
  
  def update_stock(quantity, operation = 'add')
    if operation == 'add'
      self.current_stock += quantity
    else
      self.current_stock -= quantity
    end
    save!
  end
  
  def self.categories
    distinct.pluck(:category).compact.sort
  end
end
