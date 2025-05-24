class User < ApplicationRecord
  has_secure_password
  
  # Existing associations
  has_many :customers, dependent: :destroy
  has_many :delivery_assignments, dependent: :destroy
  has_many :delivery_schedules, dependent: :destroy
  
  # New associations for delivery person functionality
  has_many :assigned_customers, class_name: 'Customer', foreign_key: 'delivery_person_id', dependent: :nullify
  has_many :deliveries, foreign_key: 'delivery_person_id', dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[admin user delivery_person] }
  validates :phone, presence: true
  
  # Scopes
  scope :delivery_people, -> { where(role: 'delivery_person') }
  scope :admins, -> { where(role: 'admin') }
  scope :regular_users, -> { where(role: 'user') }
  
  # Instance methods
  def delivery_person?
    role == 'delivery_person'
  end
  
  def admin?
    role == 'admin'
  end
  
  def can_take_customers?
    return false unless delivery_person?
    assigned_customers.count < 50
  end
  
  def available_customer_slots
    return 0 unless delivery_person?
    [50 - assigned_customers.count, 0].max
  end
  
  def customer_count
    delivery_person? ? assigned_customers.count : 0
  end
  
  # Get unassigned customers for assignment
  def self.unassigned_customers
    Customer.where(delivery_person_id: nil)
  end
  
  # Get available delivery people (those with less than 50 customers)
  def self.available_delivery_people
    delivery_people.joins("LEFT JOIN customers ON customers.delivery_person_id = users.id")
                   .group("users.id")
                   .having("COUNT(customers.id) < 50")
  end
end
