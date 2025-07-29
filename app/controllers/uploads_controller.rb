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

  # New method to upload via third-party API (same as JavaScript implementation)
  def create_via_third_party
    if params[:file].blank?
      render json: { error: 'No file provided' }, status: :bad_request
      return
    end
    
    file = params[:file]
    
    # Validate file type (optional - third-party API might have its own validation)
    unless valid_file_type?(file.content_type)
      render json: { error: 'Invalid file type.' }, status: :bad_request
      return
    end
    
    # Validate file size (max 10MB - adjust as needed)
    if file.size > 10.megabytes
      render json: { error: 'File size too large. Maximum 10MB allowed.' }, status: :bad_request
      return
    end
    
    begin
      # Upload to third-party API
      upload_result = upload_to_third_party_api(file)
      
      if upload_result[:success]
        render json: { 
          url: upload_result[:url],
          filename: file.original_filename,
          size: file.size,
          content_type: file.content_type
        }, status: :ok
      else
        render json: { error: upload_result[:error] || 'Upload failed' }, status: :internal_server_error
      end
      
    rescue => e
      Rails.logger.error "Third-party file upload error: #{e.message}"
      render json: { error: 'File upload failed' }, status: :internal_server_error
    end
  end
  
  private
  
  def valid_image_type?(content_type)
    %w[image/jpeg image/jpg image/png image/gif image/webp].include?(content_type)
  end

  # More flexible file type validation for third-party API
  def valid_file_type?(content_type)
    # Allow images and common document types
    allowed_types = %w[
      image/jpeg image/jpg image/png image/gif image/webp image/svg+xml
      application/pdf
      text/plain
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
    ]
    allowed_types.include?(content_type)
  end
  
  def generate_unique_filename(original_filename)
    extension = File.extname(original_filename)
    timestamp = Time.current.to_i
    random_string = SecureRandom.hex(8)
    "#{timestamp}_#{random_string}#{extension}"
  end

  # Upload file to third-party API using the same endpoint as JavaScript
  def upload_to_third_party_api(file)
    require 'net/http'
    require 'uri'
    
    uri = URI('https://kitintellect.tech/storage/public/api/upload/aaFacebook')
    
    # Create multipart form data
    boundary = "----WebKitFormBoundary#{SecureRandom.hex(16)}"
    
    # Build the multipart body
    body = []
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{file.original_filename}\"\r\n"
    body << "Content-Type: #{file.content_type}\r\n"
    body << "\r\n"
    body << file.read
    body << "\r\n--#{boundary}--\r\n"
    
    body_string = body.join
    
    # Create HTTP request
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    request.body = body_string
    
    # Send request
    response = http.request(request)
    
    if response.code == '200'
      begin
        result = JSON.parse(response.body)
        if result['url']
          { success: true, url: result['url'] }
        else
          { success: false, error: 'No URL returned from upload service' }
        end
      rescue JSON::ParserError
        { success: false, error: 'Invalid response from upload service' }
      end
    else
      { success: false, error: "Upload service returned status: #{response.code}" }
    end
    
  rescue => e
    Rails.logger.error "Third-party API upload error: #{e.message}"
    { success: false, error: e.message }
  end
end