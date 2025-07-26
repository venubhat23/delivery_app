class PurchaseProduct < ApplicationRecord
  has_many :purchase_invoice_items, dependent: :destroy
  has_many :purchase_invoices, through: :purchase_invoice_items
  
  validates :name, presence: true, uniqueness: true
  validates :purchase_price, :sales_price, presence: true, 
            numericality: { greater_than_or_equal_to: 0 }
  validates :measuring_unit, presence: true
  validates :opening_stock, :current_stock, presence: true, 
            numericality: { greater_than_or_equal_to: 0 }
  
  scope :active, -> { where(status: 'active') }
  scope :low_stock, -> { where('current_stock < ?', 10) }
  scope :search_by_name, ->(name) { where('name ILIKE ?', "%#{name}%") if name.present? }
  
  before_validation :set_default_status, on: :create
  
  def display_name
    "#{name} (#{measuring_unit})"
  end
  
  def update_stock(quantity, operation)
    case operation
    when 'add'
      increment!(:current_stock, quantity)
    when 'subtract'
      decrement!(:current_stock, quantity)
    end
  end
  
  def profit_margin
    return 0 if purchase_price.zero?
    ((sales_price - purchase_price) / purchase_price * 100).round(2)
  end
  
  def stock_status
    if current_stock <= 0
      'out_of_stock'
    elsif current_stock < 10
      'low_stock'
    else
      'in_stock'
    end
  end
  
  def stock_status_badge_class
    case stock_status
    when 'out_of_stock'
      'badge-danger'
    when 'low_stock'
      'badge-warning'
    else
      'badge-success'
    end
  end
  
  private
  
  def set_default_status
    self.status = 'active' if status.blank?
  end
end
