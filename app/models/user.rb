class User < ApplicationRecord
  has_secure_password
  
  # Existing associations
  has_many :delivery_assignments, dependent: :destroy
  has_many :delivery_schedules, dependent: :destroy
  
  # New associations for delivery person functionality
  has_many :assigned_customers, class_name: 'Customer', foreign_key: 'delivery_person_id', dependent: :nullify
  has_many :deliveries, foreign_key: 'delivery_person_id', dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[admin user delivery_person customer] }
  validates :phone, presence: true
  validates :employee_id, uniqueness: true, allow_blank: true
  
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
  
  def customer?
    role == 'customer'
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
  
  # Add image_url method for delivery people
  def image_url
    # Return nil or a default image URL since users table doesn't have image_url column
    # You can customize this to return a default avatar or implement image upload later
    nil
  end
end
