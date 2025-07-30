class Customer < ApplicationRecord
  # Associations
  has_secure_password
  
  # Virtual attribute for password confirmation
  attr_accessor :password_confirmation
  
  # Callbacks
  before_save :normalize_member_id

  belongs_to :user
  belongs_to :delivery_person, class_name: 'User', optional: true
  has_many :deliveries, dependent: :destroy
  has_many :delivery_assignments, dependent: :destroy
  has_many :delivery_schedules, dependent: :destroy
  has_many :invoices, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :phone_number, presence: true
  validates :address, presence: true, length: { minimum: 5, maximum: 255 }
  validates :user_id, presence: true
  validates :member_id, uniqueness: { allow_blank: true }, allow_blank: true
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


  # CSV template for bulk import
  def self.csv_template
    "name,phone_number,address,email,gst_number,pan_number,member_id,latitude,longitude\n" +
    "John Doe,9999999999,123 Main St,john@example.com,GST123,PAN123,MEM123,12.9716,77.5946\n" +
    "Jane Smith,8888888888,456 Oak Ave,jane@example.com,,,,,\n"
  end
  
  # Import customers from CSV data
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
          user: current_user
        )
        
        # Set default password as specified by user
        customer.password = "customer@123"
        customer.password_confirmation = "customer@123"
        
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
  
  # Enhanced bulk import with delivery assignments and schedules
  def self.enhanced_bulk_import(csv_data, current_user)
    require 'csv'
    
    result = {
      success: false,
      imported_count: 0,
      errors: [],
      skipped_rows: [],
      message: '',
      delivery_assignments_created: 0,
      delivery_schedules_created: 0
    }
    
    begin
      # Parse CSV data
      csv = CSV.parse(csv_data.strip, headers: true, header_converters: :symbol)
      
      if csv.empty?
        result[:message] = "CSV file is empty"
        return result
      end
      
      # Validate required headers for enhanced format
      required_headers = [:name, :phone_number, :address, :email, :gst_number, :pan_number, :delivery_person_id, :product_id, :quality, :start_date, :end_date]
      missing_headers = required_headers - csv.headers.compact.map(&:to_sym)
      
      if missing_headers.any?
        result[:message] = "Missing required columns: #{missing_headers.join(', ')}"
        return result
      end
      
      # Check user limit (maximum 50 customers)
      if csv.length > 50
        result[:message] = "Maximum 50 customers allowed per bulk import. Your file contains #{csv.length} rows."
        return result
      end
      
      imported_count = 0
      delivery_assignments_created = 0
      delivery_schedules_created = 0
      
      ActiveRecord::Base.transaction do
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
          
          # Validate delivery person exists
          delivery_person = User.find_by(id: row[:delivery_person_id], role: 'delivery_person')
          if row[:delivery_person_id].present? && delivery_person.nil?
            result[:errors] << "Row #{row_number}: Invalid delivery person ID #{row[:delivery_person_id]}"
            next
          end
          
          # Validate product exists
          product = Product.find_by(id: row[:product_id])
          if row[:product_id].present? && product.nil?
            result[:errors] << "Row #{row_number}: Invalid product ID #{row[:product_id]}"
            next
          end
          
          # Validate dates
          begin
            start_date = Date.parse(row[:start_date].to_s) if row[:start_date].present?
            end_date = Date.parse(row[:end_date].to_s) if row[:end_date].present?
            
            if start_date && end_date && start_date > end_date
              result[:errors] << "Row #{row_number}: Start date cannot be after end date"
              next
            end
          rescue ArgumentError
            result[:errors] << "Row #{row_number}: Invalid date format. Use YYYY-MM-DD format"
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
          
          # Create customer (columns 1-6)
          customer = Customer.new(
            name: row[:name].to_s.strip,
            phone_number: row[:phone_number].to_s.strip,
            address: row[:address].to_s.strip,
            email: row[:email].to_s.strip.presence,
            gst_number: row[:gst_number].to_s.strip.presence,
            pan_number: row[:pan_number].to_s.strip.presence,
            delivery_person_id: delivery_person&.id,
            user: current_user
          )
          
          # Set default password
          customer.password = "customer@123"
          customer.password_confirmation = "customer@123"
          
          if customer.save
            imported_count += 1
            
            # Create delivery schedule if product and dates are provided
            if product && start_date && end_date
              # Handle quantity for milk liters (can be 0.5)
              quantity = row[:quality].present? ? row[:quality].to_f : 1.0
              
              delivery_schedule = DeliverySchedule.new(
                customer: customer,
                user: delivery_person || current_user,
                product: product,
                frequency: 'daily', # Default frequency
                start_date: start_date,
                end_date: end_date,
                default_quantity: quantity,
                default_unit: 'liters',
                status: 'active'
              )
              
              # Allow past dates during bulk import
              delivery_schedule.skip_past_date_validation = true
              
              if delivery_schedule.save
                delivery_schedules_created += 1
                
                # Generate delivery assignments for the schedule
                assignments_created = generate_delivery_assignments_for_schedule(delivery_schedule)
                delivery_assignments_created += assignments_created
              else
                result[:errors] << "Row #{row_number}: Failed to create delivery schedule - #{delivery_schedule.errors.full_messages.join(', ')}"
              end
            end
            
          else
            error_messages = customer.errors.full_messages.join(', ')
            result[:errors] << "Row #{row_number}: #{error_messages}"
          end
        end
        
        # If there are errors, rollback the transaction
        if result[:errors].any?
          raise ActiveRecord::Rollback
        end
      end
      
      result[:success] = result[:errors].empty?
      result[:imported_count] = imported_count
      result[:delivery_assignments_created] = delivery_assignments_created
      result[:delivery_schedules_created] = delivery_schedules_created
      
      if result[:success]
        result[:message] = "Enhanced bulk import completed successfully"
      else
        result[:message] = "Import failed with errors"
      end
      
    rescue CSV::MalformedCSVError => e
      result[:message] = "Invalid CSV format: #{e.message}"
    rescue => e
      result[:message] = "Error processing CSV: #{e.message}"
    end
    
    result
  end

  # Enhanced CSV template for bulk import with delivery assignments
  def self.enhanced_csv_template
    "name,phone_number,address,email,gst_number,pan_number,delivery_person_id,product_id,quality,start_date,end_date\n" +
    "John Doe,9999999999,123 Main St Delhi,john@example.com,GST123,PAN123,1,1,5,2024-01-01,2024-01-31\n" +
    "Jane Smith,8888888888,456 Oak Ave Mumbai,jane@example.com,GST456,PAN456,2,2,3,2024-01-01,2024-01-31\n"
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

  def normalize_member_id
    # Convert empty string member_id to nil to avoid unique constraint violations
    self.member_id = nil if member_id.blank?
  end

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
    today = Date.current
    
    while current_date <= schedule.end_date
      # Create assignment for every day in the date range
      # Determine status based on whether the date is in the past
      assignment_status = current_date < today ? 'completed' : 'pending'
      
      assignments << {
        delivery_schedule_id: schedule.id,
        customer_id: id,
        user_id: schedule.user_id,
        product_id: schedule.product_id,
        scheduled_date: current_date,
        status: assignment_status,
        quantity: schedule.default_quantity || 1,
        unit: schedule.default_unit || 'pieces',
        created_at: Time.current,
        updated_at: Time.current
      }
      
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

  # Helper method to generate delivery assignments for a schedule
  def self.generate_delivery_assignments_for_schedule(schedule)
    assignments_created = 0
    current_date = schedule.start_date
    while current_date <= schedule.end_date
      # Determine status based on whether the date is in the past

      assignment = DeliveryAssignment.new(
        delivery_schedule: schedule,
        customer: schedule.customer,
        user: schedule.user,
        product: schedule.product,
        scheduled_date: current_date,
        status: 'completed', # ✅ Use calculated status
        quantity: schedule.default_quantity,
        unit: schedule.default_unit || 'pieces'
      )
      assignments_created += 1 if assignment.save

      current_date += 1.day
    end

    assignments_created
  end

end