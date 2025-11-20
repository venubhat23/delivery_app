class Api::UploadController < ApplicationController
  skip_before_action :require_login

  def create
    unless params[:file].present?
      return render json: { error: 'No file provided' }, status: :bad_request
    end

    file = params[:file]

    # Validate file type
    allowed_types = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
    unless allowed_types.include?(file.content_type)
      return render json: { error: 'Invalid file type. Only images are allowed.' }, status: :bad_request
    end

    # Validate file size (max 10MB)
    max_size = 10.megabytes
    if file.size > max_size
      return render json: { error: 'File too large. Maximum size is 10MB.' }, status: :bad_request
    end

    begin
      # Get folder name from params
      folder_name = params[:folder_name] || 'general'

      # Create directory if it doesn't exist
      upload_dir = Rails.root.join('public', 'uploads', folder_name)
      FileUtils.mkdir_p(upload_dir) unless Dir.exist?(upload_dir)

      # Generate unique filename
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      random_id = SecureRandom.hex(6)
      file_extension = File.extname(file.original_filename)
      safe_filename = file.original_filename.gsub(/[^a-zA-Z0-9\-_\.]/, '_')
      filename = "#{timestamp}_#{random_id}_#{safe_filename}"

      # Full file path
      file_path = upload_dir.join(filename)

      # Save file
      File.open(file_path, 'wb') do |f|
        f.write(file.read)
      end

      # Generate public URL
      url = "/uploads/#{folder_name}/#{filename}"

      render json: {
        url: url,
        filename: filename,
        original_filename: file.original_filename,
        size: file.size,
        content_type: file.content_type
      }, status: :ok

    rescue => e
      Rails.logger.error "File upload failed: #{e.message}"
      render json: { error: "Upload failed: #{e.message}" }, status: :internal_server_error
    end
  end
end