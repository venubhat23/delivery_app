class CustomerAddress < ApplicationRecord
  belongs_to :customer

  validates :address_type, presence: true, inclusion: { in: %w[home work other] }
  validates :street_address, presence: true, length: { maximum: 500 }
  validates :city, presence: true, length: { maximum: 100 }
  validates :state, presence: true, length: { maximum: 100 }
  validates :pincode, presence: true, format: { with: /\A\d{6}\z/, message: "must be 6 digits" }

  scope :default_address, -> { where(is_default: true) }
  scope :by_type, ->(type) { where(address_type: type) }
  scope :home_addresses, -> { where(address_type: 'home') }
  scope :work_addresses, -> { where(address_type: 'work') }

  before_save :ensure_single_default

  def full_address
    [street_address, landmark, city, state, pincode].compact.join(', ')
  end

  def short_address
    "#{street_address.truncate(50)}, #{city}"
  end

  def set_as_default!
    CustomerAddress.transaction do
      customer.customer_addresses.update_all(is_default: false)
      update!(is_default: true)
    end
  end

  def address_type_label
    address_type.humanize
  end

  private

  def ensure_single_default
    if is_default? && customer
      customer.customer_addresses.where.not(id: id).update_all(is_default: false)
    end
  end
end
