class Api::UploadController < ApplicationController
  skip_before_action :require_login

  def create
    unless params[:file].present?
      return render json: { error: 'No file provided' }, status: :bad_request
    end

    file = params[:file]

    # Get folder name from params
    folder_name = params[:folder_name] || 'uploads'

    # Generate unique filename with folder
    filename = "#{folder_name}/#{SecureRandom.uuid}_#{file.original_filename}"

    begin
      # Upload to S3
      s3_client = Aws::S3::Client.new
      bucket_name = 'file-upload-2024-milk-delivery-latest-1'

      s3_client.put_object(
        bucket: bucket_name,
        key: filename,
        body: file.read,
        content_type: file.content_type
      )

      # Generate public URL
      url = "https://#{bucket_name}.s3.amazonaws.com/#{filename}"

      render json: { url: url }, status: :ok

    rescue Aws::S3::Errors::ServiceError => e
      render json: { error: "S3 upload failed: #{e.message}" }, status: :internal_server_error
    rescue => e
      render json: { error: "Upload failed: #{e.message}" }, status: :internal_server_error
    end
  end
end