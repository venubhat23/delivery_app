class Party < ApplicationRecord
  belongs_to :user
  
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :mobile_number, presence: true, format: { with: /\A[0-9]{10}\z/, message: "must be 10 digits" }
  validates :user_id, presence: true
  
  # Scopes
  scope :search, ->(term) { where("name ILIKE ? OR mobile_number ILIKE ?", "%#{term}%", "%#{term}%") }
  scope :by_user, ->(user) { where(user: user) }
  scope :recent, -> { order(created_at: :desc) }

  # CSV template for bulk import
  def self.csv_template
    "name,mobile_number,gst_number,shipping_address,shipping_pincode,shipping_city,shipping_state,billing_address,billing_pincode\n" +
    "Sample Party 1,8999999990,09AABCS1429B1ZS,j1204 salar puria,500068,Bangalore,Karnataka,j1204 salar puria,500068\n" +
    "Sample Party 2,8999999991,09AABCS1429B1ZS,255/93 Shastri Nagar Rakabganj Lucknow,226004,Lucknow,Uttar Pradesh,j1205 salar puria,500068\n" +
    "Sample Party 3,8999999992,24AABCS1429B1ZS,255/93 BTM Bangalore,560102,Bangalore,Karnataka,j1206 salar puria,500068\n"
  end
  
  # Import parties from CSV data
  def self.import_from_csv(csv_data, current_user)
    require 'csv'
    
    begin
      csv = CSV.parse(csv_data.strip, headers: true, header_converters: :symbol)
      
      # Validate headers
      required_headers = [:name, :mobile_number]
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
      
      # Limit to 4000 parties max as shown in the image
      rows_to_process = csv.first(4000)
      imported_count = 0
      errors = []
      skipped_rows = []
      
      rows_to_process.each_with_index do |row, index|
        begin
          # Skip empty rows
          next if row.to_h.values.all?(&:blank?)
          
          party_params = {
            name: row[:name]&.strip,
            mobile_number: row[:mobile_number]&.strip,
            gst_number: row[:gst_number]&.strip,
            shipping_address: row[:shipping_address]&.strip,
            shipping_pincode: row[:shipping_pincode]&.strip,
            shipping_city: row[:shipping_city]&.strip,
            shipping_state: row[:shipping_state]&.strip,
            billing_address: row[:billing_address]&.strip,
            billing_pincode: row[:billing_pincode]&.strip,
            user: current_user
          }
          
          # Remove empty values
          party_params.reject! { |k, v| v.blank? }
          
          party = Party.new(party_params)
          
          if party.save
            imported_count += 1
          else
            errors << {
              row: index + 2, # +2 because index starts at 0 and we have header row
              data: row.to_h,
              errors: party.errors.full_messages
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
end