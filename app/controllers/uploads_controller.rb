class UploadsController < ApplicationController
  before_action :require_login
  
  def create
    if params[:file].blank?
      render json: { error: 'No file provided' }, status: :bad_request
      return
    end
    
    file = params[:file]
    
    # Validate file type
    unless valid_image_type?(file.content_type)
      render json: { error: 'Invalid file type. Only images are allowed.' }, status: :bad_request
      return
    end
    
    # Validate file size (max 5MB)
    if file.size > 5.megabytes
      render json: { error: 'File size too large. Maximum 5MB allowed.' }, status: :bad_request
      return
    end
    
    begin
      # Generate unique filename
      filename = generate_unique_filename(file.original_filename)
      
      # Ensure upload directory exists
      upload_dir = Rails.root.join('public', 'uploads', 'images')
      FileUtils.mkdir_p(upload_dir)
      
      # Save file
      file_path = upload_dir.join(filename)
      File.open(file_path, 'wb') do |f|
        f.write(file.read)
      end
      
      # Generate URL
      file_url = request.base_url + "/uploads/images/#{filename}"
      
      render json: { 
        url: file_url,
        filename: filename,
        size: file.size,
        content_type: file.content_type
      }, status: :ok
      
    rescue => e
      Rails.logger.error "File upload error: #{e.message}"
      render json: { error: 'File upload failed' }, status: :internal_server_error
    end
  end
  
  private
  
  def valid_image_type?(content_type)
    %w[image/jpeg image/jpg image/png image/gif image/webp].include?(content_type)
  end
  
  def generate_unique_filename(original_filename)
    extension = File.extname(original_filename)
    timestamp = Time.current.to_i
    random_string = SecureRandom.hex(8)
    "#{timestamp}_#{random_string}#{extension}"
  end
end