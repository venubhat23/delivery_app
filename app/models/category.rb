class Category < ApplicationRecord
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :description, length: { maximum: 500 }
  validates :color, presence: true, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color" }

  # Associations
  has_many :products, dependent: :nullify

  # Scopes
  scope :with_products, -> { joins(:products).distinct }
  scope :without_products, -> { left_joins(:products).where(products: { id: nil }) }

  # Instance methods
  def products_count
    products.count
  end

  def total_products_value
    products.sum { |product| product.available_quantity.to_f * product.price.to_f }
  end

  def display_name
    name
  end

  # Class methods
  def self.colors_for_select
    [
      ['Blue', '#007bff'],
      ['Green', '#28a745'],
      ['Orange', '#fd7e14'],
      ['Purple', '#6f42c1'],
      ['Red', '#dc3545'],
      ['Yellow', '#ffc107'],
      ['Pink', '#e83e8c'],
      ['Teal', '#20c997'],
      ['Gray', '#6c757d'],
      ['Dark', '#343a40']
    ]
  end
end