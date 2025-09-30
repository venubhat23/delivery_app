class S3ProxyController < ApplicationController
  def serve_invoice_pdf
    token = params[:token]
    filename = params[:filename]

    # Find invoice by share token for security
    invoice = Invoice.find_by(share_token: token)

    if invoice.nil?
      return render json: { error: 'Invoice not found' }, status: :not_found
    end

    begin
      # Get file from S3
      s3_client = Aws::S3::Client.new(
        region: Rails.application.credentials.dig(:aws, :region) || ENV['AWS_REGION'] || 'ap-south-1',
        access_key_id: Rails.application.credentials.dig(:aws, :access_key_id) || ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key) || ENV['AWS_SECRET_ACCESS_KEY']
      )

      bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET']
      s3_key = "invoices/#{token}/#{filename}"

      # Stream file from S3
      response = s3_client.get_object(bucket: bucket_name, key: s3_key)

      # Set proper headers
      response.set_header('Content-Type', 'application/pdf')
      response.set_header('Content-Disposition', "inline; filename=\"#{filename}\"")
      response.set_header('Cache-Control', 'public, max-age=3600')

      # Stream the PDF content
      render body: response.body.read, content_type: 'application/pdf'

    rescue Aws::S3::Errors::NoSuchKey
      # Fallback to local file if S3 doesn't have it
      local_path = Rails.root.join('public', 'invoices', filename)

      if File.exist?(local_path)
        send_file local_path, type: 'application/pdf', disposition: 'inline'
      else
        render json: { error: 'File not found' }, status: :not_found
      end

    rescue => e
      Rails.logger.error "S3 proxy error: #{e.message}"
      render json: { error: 'File access error' }, status: :internal_server_error
    end
  end
end