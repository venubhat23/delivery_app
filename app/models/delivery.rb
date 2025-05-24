# app/models/delivery.rb
class Delivery < ApplicationRecord
  belongs_to :customer
  belongs_to :delivery_person, class_name: 'User', foreign_key: 'delivery_person_id'
  
  has_many :delivery_items, dependent: :destroy
  has_many :products, through: :delivery_items
  
  validates :status, presence: true
  validates :delivery_date, presence: true
end

