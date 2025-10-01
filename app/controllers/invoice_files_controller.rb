class InvoiceFilesController < ApplicationController
  # Skip authentication for public PDF access
  skip_before_action :require_login

  def show
    filename = params[:filename]

    # Extract invoice ID from filename (e.g., "123.pdf" -> "123")
    invoice_id = filename.gsub('.pdf', '')

    begin
      # Find invoice by ID for security check
      invoice = Invoice.find(invoice_id)

      # Generate S3 key based on invoice
      s3_key = generate_s3_key(invoice, filename)

      # Try to serve from S3 first
      if s3_configured?
        serve_from_s3(s3_key, filename)
      else
        # Fallback to local file
        serve_from_local(filename)
      end

    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Invoice not found' }, status: :not_found
    rescue => e
      Rails.logger.error "Invoice file serving error: #{e.message}"
      render json: { error: 'File access error' }, status: :internal_server_error
    end
  end

  private

  def s3_configured?
    ENV['AWS_ACCESS_KEY_ID'].present? &&
    ENV['AWS_SECRET_ACCESS_KEY'].present? &&
    ENV['AWS_S3_BUCKET'].present?
  end

  def serve_from_s3(s3_key, filename)
    s3_client = Aws::S3::Client.new(
      region: ENV['AWS_REGION'] || 'ap-south-1',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )

    bucket_name = ENV['AWS_S3_BUCKET']

    begin
      # Get file from S3
      response = s3_client.get_object(bucket: bucket_name, key: s3_key)

      # Set proper headers for PDF
      response.set_header('Content-Type', 'application/pdf')
      response.set_header('Content-Disposition', "inline; filename=\"#{filename}\"")
      response.set_header('Cache-Control', 'public, max-age=3600')

      # Stream the PDF content
      render body: response.body.read, content_type: 'application/pdf'

    rescue Aws::S3::Errors::NoSuchKey
      # File not in S3, try local fallback
      serve_from_local(filename)
    end
  end

  def serve_from_local(filename)
    # Try different local paths
    local_paths = [
      Rails.root.join('public', 'invoices', filename),
      Rails.root.join('public', 'invoices', "invoice_#{filename}")
    ]

    local_path = local_paths.find { |path| File.exist?(path) }

    if local_path
      send_file local_path,
                type: 'application/pdf',
                disposition: 'inline',
                filename: filename
    else
      render json: { error: 'File not found' }, status: :not_found
    end
  end

  def generate_s3_key(invoice, filename)
    # Try multiple S3 key patterns
    possible_keys = [
      "invoices/#{filename}",
      "invoices/invoice_#{invoice.id}_#{invoice.share_token}.pdf",
      "invoices/#{invoice.share_token}/#{filename}",
      "invoices/#{invoice.id}/#{filename}"
    ]

    # Return the first one that exists, or default to simple pattern
    s3_client = Aws::S3::Client.new(
      region: ENV['AWS_REGION'] || 'ap-south-1',
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )

    bucket_name = ENV['AWS_S3_BUCKET']

    possible_keys.each do |key|
      begin
        s3_client.head_object(bucket: bucket_name, key: key)
        return key # File exists, use this key
      rescue Aws::S3::Errors::NotFound
        next # Try next key pattern
      end
    end

    # Default key if none found
    "invoices/#{filename}"
  end
end