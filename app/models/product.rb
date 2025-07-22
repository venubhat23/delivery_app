class Product < ApplicationRecord
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :unit_type, presence: true, inclusion: { 
    in: %w[liters kg pieces bottles packets],
    message: "%{value} is not a valid unit type" 
  }
  validates :price, presence: true, numericality: { 
    greater_than: 0,
    message: "must be greater than 0" 
  }
  validates :description, length: { maximum: 500 }

  # Associations
  belongs_to :category
  has_many :delivery_items, dependent: :destroy
  has_many :deliveries, through: :delivery_items
  has_many :delivery_assignments, dependent: :destroy
  has_many :invoice_items, dependent: :destroy
  has_many :invoices, through: :invoice_items

  # Scopes
  scope :low_stock, -> { where('available_quantity < ?', 10) }
  scope :in_stock, -> { where('available_quantity > ?', 0) }
  scope :by_unit_type, ->(unit) { where(unit_type: unit) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :search, ->(term) { where("name ILIKE ? OR description ILIKE ?", "%#{term}%", "%#{term}%") }

  # Instance methods
  def low_stock?
    available_quantity.to_f < 10
  end

  def out_of_stock?
    available_quantity.to_f <= 0
  end

  def stock_status
    if out_of_stock?
      'Out of Stock'
    elsif low_stock?
      'Low Stock'
    else
      'In Stock'
    end
  end

  def stock_status_class
    if out_of_stock?
      'danger'
    elsif low_stock?
      'warning'
    else
      'success'
    end
  end

  def total_value
    (available_quantity.to_f * price.to_f).round(2)
  end

  def formatted_price
    "$#{price.to_f.round(2)}"
  end

  def display_name
    "#{name} (#{available_quantity} #{unit_type})"
  end

  def category_name
    category&.name || 'Uncategorized'
  end

  def category_color
    category&.color || '#6c757d'
  end

  # Class methods
  def self.total_value
    sum { |product| product.total_value }
  end

  def self.total_quantity
    sum(:available_quantity)
  end

  def self.unit_types_for_select
    [
      ['Liters', 'liters'],
      ['Kilograms', 'kg'],
      ['Pieces', 'pieces'],
      ['Bottles', 'bottles'],
      ['Packets', 'packets']
    ]
  end
end