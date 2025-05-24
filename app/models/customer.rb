class Customer < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :delivery_person, class_name: 'User', optional: true
  has_many :deliveries, dependent: :destroy
  has_many :delivery_assignments, dependent: :destroy
  has_many :delivery_schedules, dependent: :destroy
  has_many :invoices, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :address, presence: true, length: { minimum: 5, maximum: 255 }
  validates :user_id, presence: true
  validates :latitude, numericality: { 
    greater_than_or_equal_to: -90, 
    less_than_or_equal_to: 90,
    allow_blank: true,
    message: "must be between -90 and 90 degrees"
  }
  validates :longitude, numericality: { 
    greater_than_or_equal_to: -180, 
    less_than_or_equal_to: 180,
    allow_blank: true,
    message: "must be between -180 and 180 degrees"
  }

  # Custom validation for delivery person assignment
  validate :delivery_person_capacity_check, if: :delivery_person_id_changed?

  # Custom validation to ensure both lat and lng are provided together
  validate :coordinates_presence

  # Scopes
  scope :assigned, -> { where.not(delivery_person_id: nil) }
  scope :unassigned, -> { where(delivery_person_id: nil) }
  scope :with_coordinates, -> { where.not(latitude: nil, longitude: nil) }
  scope :without_coordinates, -> { where(latitude: nil, longitude: nil) }
  scope :search, ->(term) { where("name ILIKE ? OR address ILIKE ?", "%#{term}%", "%#{term}%") }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_delivery_person, ->(dp) { where(delivery_person: dp) }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def assigned?
    delivery_person.present?
  end

  def has_coordinates?
    latitude.present? && longitude.present?
  end

  def coordinates
    return nil unless has_coordinates?
    [latitude.to_f, longitude.to_f]
  end

  def coordinates_string
    return "No coordinates" unless has_coordinates?
    "#{latitude.to_f.round(6)}, #{longitude.to_f.round(6)}"
  end

  def google_maps_url
    return nil unless has_coordinates?
    "https://www.google.com/maps/search/?api=1&query=#{latitude},#{longitude}"
  end

  def initials
    name.split.map(&:first).join.upcase[0, 2]
  end

  def full_address_with_coordinates
    address_parts = [address]
    address_parts << coordinates_string if has_coordinates?
    address_parts.join(" | ")
  end

  def customer_since
    created_at.strftime("%B %Y")
  end

  def formatted_id
    "##{id.to_s.rjust(6, '0')}"
  end

  def delivery_person_name
    delivery_person&.name || "Not Assigned"
  end

  # Delivery related methods
  def total_deliveries
    deliveries.count
  end

  def pending_deliveries
    deliveries.where(status: 'pending').count
  end

  def completed_deliveries
    deliveries.where(status: 'completed').count
  end

  def last_delivery_date
    deliveries.order(:delivery_date).last&.delivery_date
  end

  def delivery_assignments_count
    delivery_assignments.count
  end

  def active_schedules
    delivery_schedules.where(status: 'active')
  end

  def has_active_schedule?
    active_schedules.exists?
  end

  # Invoice related methods
  def total_invoices
    invoices.count
  end

  def total_invoice_amount
    invoices.sum(:total_amount) || 0
  end

  def pending_invoice_amount
    invoices.where(status: 'pending').sum(:total_amount) || 0
  end

  # Scheduling methods
  def create_schedule_with_assignments(schedule_params)
    ActiveRecord::Base.transaction do
      # Create the schedule
      schedule = delivery_schedules.create!(schedule_params.merge(status: 'active'))
      
      # Generate assignments based on frequency
      assignments = generate_assignments_for_schedule(schedule)
      
      # Bulk create assignments
      DeliveryAssignment.insert_all(assignments) if assignments.any?
      
      schedule
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create schedule: #{e.message}"
    false
  end

  # Distance calculation (if you want to add distance-based features later)
  def distance_from(lat, lng)
    return nil unless has_coordinates?
    
    # Using Haversine formula for distance calculation
    rad_per_deg = Math::PI / 180  # PI / 180
    rkm = 6371                    # Earth radius in kilometers
    rm = rkm * 1000               # Radius in meters

    dlat_rad = (lat - latitude.to_f) * rad_per_deg
    dlon_rad = (lng - longitude.to_f) * rad_per_deg

    lat1_rad, lat2_rad = latitude.to_f * rad_per_deg, lat * rad_per_deg

    a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    rm * c # Distance in meters
  end

  # Class methods
  def self.with_pending_deliveries
    joins(:deliveries).where(deliveries: { status: 'pending' }).distinct
  end

  def self.without_deliveries
    left_joins(:deliveries).where(deliveries: { id: nil })
  end

  def self.active_customers
    joins(:deliveries).where('deliveries.created_at > ?', 3.months.ago).distinct
  end

  def self.available_for_assignment
    unassigned.includes(:user)
  end

  private

  def delivery_person_capacity_check
    return unless delivery_person_id.present?
    
    # Check if delivery person exists and has capacity
    dp = User.find_by(id: delivery_person_id, role: 'delivery_person')
    
    if dp.nil?
      errors.add(:delivery_person, "must be a valid delivery person")
      return
    end
    
    # Check capacity (excluding current customer if updating)
    current_count = dp.assigned_customers.where.not(id: self.id).count
    
    if current_count >= 50
      errors.add(:delivery_person, "has reached maximum capacity of 50 customers")
    end
  end

  def coordinates_presence
    if latitude.present? && longitude.blank?
      errors.add(:longitude, "must be provided if latitude is provided")
    elsif longitude.present? && latitude.blank?
      errors.add(:latitude, "must be provided if longitude is provided")
    end
  end

  def generate_assignments_for_schedule(schedule)
    return [] unless schedule.persisted?
    
    assignments = []
    current_date = schedule.start_date
    
    while current_date <= schedule.end_date
      # Skip if frequency doesn't match (for now we'll do daily, but can be enhanced)
      if should_create_assignment_for_date?(current_date, schedule.frequency)
        assignments << {
          delivery_schedule_id: schedule.id,
          customer_id: id,
          user_id: schedule.user_id,
          product_id: schedule.product_id,
          scheduled_date: current_date,
          status: 'pending',
          quantity: schedule.default_quantity || 1,
          unit: schedule.default_unit || 'pieces',
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      
      current_date += 1.day
    end
    
    assignments
  end

  def should_create_assignment_for_date?(date, frequency)
    case frequency
    when 'daily'
      true
    when 'weekly'
      date.wday == 1 # Monday
    when 'monthly'
      date.day == 1
    else
      true # Default to daily
    end
  end
end