class UploadsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]
  before_action :require_login

  def create
    begin
      uploaded_file = params[:file]
      
      if uploaded_file.blank?
        render json: { error: 'No file provided' }, status: :bad_request
        return
      end

      # Validate file type
      unless valid_file_type?(uploaded_file)
        render json: { error: 'Invalid file type. Only images are allowed.' }, status: :bad_request
        return
      end

      # Validate file size (5MB max)
      if uploaded_file.size > 5.megabytes
        render json: { error: 'File size too large. Maximum 5MB allowed.' }, status: :bad_request
        return
      end

      # Create unique filename
      filename = generate_unique_filename(uploaded_file.original_filename)
      
      # Save file to public/uploads directory
      upload_path = Rails.root.join('public', 'uploads', filename)
      FileUtils.mkdir_p(File.dirname(upload_path))
      
      File.open(upload_path, 'wb') do |file|
        file.write(uploaded_file.read)
      end

      # Return the URL
      file_url = "#{request.base_url}/uploads/#{filename}"
      
      render json: { 
        url: file_url,
        filename: filename,
        size: uploaded_file.size,
        content_type: uploaded_file.content_type
      }

    rescue StandardError => e
      Rails.logger.error "File upload error: #{e.message}"
      render json: { error: 'File upload failed' }, status: :internal_server_error
    end
  end

  private

  def valid_file_type?(file)
    allowed_types = %w[image/jpeg image/jpg image/png image/gif image/webp]
    allowed_types.include?(file.content_type&.downcase)
  end

  def generate_unique_filename(original_filename)
    extension = File.extname(original_filename)
    basename = File.basename(original_filename, extension)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    random_string = SecureRandom.hex(8)
    "#{basename}_#{timestamp}_#{random_string}#{extension}"
  end
end