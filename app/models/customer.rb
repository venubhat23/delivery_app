class Customer < ApplicationRecord
  # Password authentication
  has_secure_password
  
  # Virtual attribute for password confirmation
  attr_accessor :password_confirmation
  
  # Associations
  belongs_to :delivery_person, class_name: 'User', optional: true
  has_many :deliveries, dependent: :destroy
  has_many :delivery_assignments, dependent: :destroy
  has_many :delivery_schedules, dependent: :destroy
  has_many :invoices, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone_number, presence: true, uniqueness: true, format: { with: /\A[0-9]{10}\z/, message: "must be 10 digits" }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
  validates :password_confirmation, presence: true, if: -> { new_record? && password.present? }
  validate :passwords_match, if: -> { password.present? && password_confirmation.present? }
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
  scope :by_delivery_person, ->(dp) { where(delivery_person: dp) }
  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(is_active: true) }


  # CSV template for bulk import
  def self.csv_template
    "name,phone_number,address,email,gst_number,pan_number,member_id,latitude,longitude\n" +
    "John Doe,9999999999,123 Main St,john@example.com,GST123,PAN123,MEM123,12.9716,77.5946\n" +
    "Jane Smith,8888888888,456 Oak Ave,jane@example.com,,,,,\n"
  end
  
  # Import customers from CSV data
  def self.import_from_csv(csv_data, current_user = nil)
    require 'csv'
    
    begin
      csv = CSV.parse(csv_data.strip, headers: true, header_converters: :symbol)
      
      # Validate headers
      required_headers = [:name, :phone_number, :address, :email]
      missing_headers = required_headers - csv.headers.compact.map(&:to_sym)
      
      if missing_headers.any?
        return {
          success: false,
          message: "Missing required columns: #{missing_headers.join(', ')}",
          imported_count: 0,
          errors: [],
          skipped_rows: []
        }
      end
      
      # Limit to 50 customers max
      rows_to_process = csv.first(50)
      imported_count = 0
      errors = []
      skipped_rows = []
      
      rows_to_process.each_with_index do |row, index|
        begin
          # Skip empty rows
          next if row.to_h.values.all?(&:blank?)
          
          customer_params = {
            name: row[:name]&.strip,
            phone_number: row[:phone_number]&.strip,
            address: row[:address]&.strip,
            email: row[:email]&.strip,
            gst_number: row[:gst_number]&.strip,
            pan_number: row[:pan_number]&.strip,
            member_id: row[:member_id]&.strip,
            latitude: row[:latitude]&.strip,
            longitude: row[:longitude]&.strip,
            password: 'default123' # Default password for bulk import
          }
          
          # Remove empty values
          customer_params.reject! { |k, v| v.blank? }
          
          # Convert coordinates to float if present
          if customer_params[:latitude].present?
            customer_params[:latitude] = customer_params[:latitude].to_f
          end
          if customer_params[:longitude].present?
            customer_params[:longitude] = customer_params[:longitude].to_f
          end
          
          customer = Customer.new(customer_params)
          
          if customer.save
            imported_count += 1
          else
            errors << {
              row: index + 2, # +2 because index starts at 0 and we have header row
              data: row.to_h,
              errors: customer.errors.full_messages
            }
            skipped_rows << row.to_h
          end
          
        rescue => e
          errors << {
            row: index + 2,
            data: row.to_h,
            errors: [e.message]
          }
          skipped_rows << row.to_h
        end
      end
      
      {
        success: true,
        message: "Import completed successfully",
        imported_count: imported_count,
        total_processed: rows_to_process.count,
        errors: errors,
        skipped_rows: skipped_rows
      }
      
    rescue CSV::MalformedCSVError => e
      {
        success: false,
        message: "Invalid CSV format: #{e.message}",
        imported_count: 0,
        errors: [],
        skipped_rows: []
      }
    rescue => e
      {
        success: false,
        message: "Error processing CSV: #{e.message}",
        imported_count: 0,
        errors: [],
        skipped_rows: []
      }
    end
  end
  
  def self.import_from_csv(csv_data, current_user)
    require 'csv'
    
    result = {
      success: false,
      imported_count: 0,
      errors: [],
      skipped_rows: [],
      message: ''
    }
    
    begin
      # Parse CSV data
      csv = CSV.parse(csv_data.strip, headers: true, header_converters: :symbol)
      
      if csv.empty?
        result[:message] = "CSV file is empty"
        return result
      end
      
      # Validate required headers
      required_headers = [:name, :phone_number, :address]
      missing_headers = required_headers - csv.headers.compact.map(&:to_sym)
      
      if missing_headers.any?
        result[:message] = "Missing required columns: #{missing_headers.join(', ')}"
        return result
      end
      
      imported_count = 0
      csv.each_with_index do |row, index|
        row_number = index + 2 # +2 because index starts at 0 and we have headers
        
        # Skip empty rows
        if row[:name].blank? && row[:phone_number].blank? && row[:address].blank?
          result[:skipped_rows] << "Row #{row_number}: Empty row"
          next
        end
        
        # Validate required fields
        if row[:name].blank?
          result[:errors] << "Row #{row_number}: Name is required"
          next
        end
        
        if row[:phone_number].blank?
          result[:errors] << "Row #{row_number}: Phone number is required"
          next
        end
        
        if row[:address].blank?
          result[:errors] << "Row #{row_number}: Address is required"
          next
        end
        
        # Check if customer already exists
        existing_customer = Customer.find_by(
          name: row[:name].to_s.strip,
          phone_number: row[:phone_number].to_s.strip
        )
        
        if existing_customer
          result[:errors] << "Row #{row_number}: Customer '#{row[:name]}' with phone '#{row[:phone_number]}' already exists"
          next
        end
        
        # Create customer
        customer = Customer.new(
          name: row[:name].to_s.strip,
          phone_number: row[:phone_number].to_s.strip,
          address: row[:address].to_s.strip,
          email: row[:email].to_s.strip.presence,
          gst_number: row[:gst_number].to_s.strip.presence,
          pan_number: row[:pan_number].to_s.strip.presence,
          member_id: row[:member_id].to_s.strip.presence,
          password: 'default123' # Default password for bulk import
        )
        
        # Handle coordinates if provided
        if row[:latitude].present? && row[:longitude].present?
          customer.latitude = row[:latitude].to_f
          customer.longitude = row[:longitude].to_f
        end
        
        if customer.save
          imported_count += 1
        else
          error_messages = customer.errors.full_messages.join(', ')
          result[:errors] << "Row #{row_number}: #{error_messages}"
        end
      end
      
      result[:success] = true
      result[:imported_count] = imported_count
      result[:message] = "Import completed successfully"
      
    rescue CSV::MalformedCSVError => e
      result[:message] = "Invalid CSV format: #{e.message}"
    rescue => e
      result[:message] = "Error processing CSV: #{e.message}"
    end
    
    result
  end
  
  # Method to get CSV template
  def self.csv_template
    "name,phone_number,address,email,gst_number,pan_number,member_id,latitude,longitude\n" +
    "John Doe,9999999999,123 Main St,john@example.com,GST123,PAN123,MEM123,12.9716,77.5946\n" +
    "Jane Smith,8888888888,456 Oak Ave,jane@example.com,,,,,\n"
  end
  
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

  def passwords_match
    unless password == password_confirmation
      errors.add(:password_confirmation, "doesn't match password")
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