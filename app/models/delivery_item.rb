# app/models/delivery_item.rb
class DeliveryItem < ApplicationRecord
  belongs_to :delivery
  belongs_to :product
  
  validates :quantity, presence: true, numericality: { greater_than: 0 }
end
