class SalesCustomer < ApplicationRecord
  has_many :sales_invoices, foreign_key: 'sales_customer_id', dependent: :restrict_with_error
  
  validates :name, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone_number, presence: true
  validates :gst_number, format: { with: /\A[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\z/ }, allow_blank: true
  
  scope :active, -> { where(is_active: true) }
  scope :search_by_name, ->(name) { where('name ILIKE ?', "%#{name}%") if name.present? }
  
  def display_name
    "#{name} - #{city}"
  end
  
  def full_address
    [address, city, state, pincode].compact.join(', ')
  end
  
  def shipping_address_display
    shipping_address.present? ? shipping_address : full_address
  end
  
  def customer_type
    'SalesCustomer'
  end
end