class PartiesController < ApplicationController
  before_action :require_login
  before_action :set_party, only: [:show, :edit, :update, :destroy]
  
  def index
    @parties = Party.includes(:user).by_user(current_user)
    
    # Search functionality
    if params[:search].present?
      @parties = @parties.search(params[:search])
    end
    
    @parties = @parties.recent
    @total_parties = @parties.count
  end
  
  def show
  end
  
  def new
    @party = Party.new
  end
  
  def create
    @party = Party.new(party_params)
    @party.user = current_user
    
    if @party.save
      redirect_to @party, notice: 'Party was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @party.update(party_params)
      redirect_to @party, notice: 'Party was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @party.destroy
    redirect_to parties_url, notice: 'Party was successfully deleted.'
  end
  
  # Bulk import form
  def bulk_import
    @csv_template = Party.csv_template
  end
  
  # Process bulk import
  def process_bulk_import
    csv_data = params[:csv_data]
    
    if csv_data.blank?
      render json: { 
        success: false, 
        message: "Please paste CSV data" 
      }
      return
    end
    
    result = Party.import_from_csv(csv_data, current_user)
    
    render json: result
  end
  
  # AJAX validation for CSV
  def validate_csv
    csv_data = params[:csv_data]
    
    if csv_data.blank?
      render json: { valid: false, message: "Please paste CSV data" }
      return
    end
    
    begin
      require 'csv'
      csv = CSV.parse(csv_data.strip, headers: true, header_converters: :symbol)
      
      required_headers = [:name, :mobile_number]
      missing_headers = required_headers - csv.headers.compact.map(&:to_sym)
      
      if missing_headers.any?
        render json: { 
          valid: false, 
          message: "Missing required columns: #{missing_headers.join(', ')}" 
        }
      else
        render json: { 
          valid: true, 
          message: "CSV format is valid. Found #{csv.count} rows ready for import.",
          row_count: csv.count,
          headers: csv.headers
        }
      end
    rescue CSV::MalformedCSVError => e
      render json: { valid: false, message: "Invalid CSV format: #{e.message}" }
    rescue => e
      render json: { valid: false, message: "Error validating CSV: #{e.message}" }
    end
  end
  
  # Download CSV template
  def download_template
    template_content = Party.csv_template
    
    respond_to do |format|
      format.csv do
        send_data template_content,
                  filename: 'parties_template.csv',
                  type: 'text/csv',
                  disposition: 'attachment'
      end
    end
  end
  
  private
  
  def set_party
    @party = Party.find(params[:id])
  end
  
  def party_params
    params.require(:party).permit(
      :name, :mobile_number, :gst_number, :shipping_address, 
      :shipping_pincode, :shipping_city, :shipping_state,
      :billing_address, :billing_pincode
    )
  end
end