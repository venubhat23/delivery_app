# app/services/public_pdf_service.rb
class PublicPdfService
  def self.generate_invoice_pdf(invoice)
    new(invoice).generate_pdf
  end

  def initialize(invoice)
    @invoice = invoice
    # Configure AWS S3 client for HTTPS URLs
    @s3_client = Aws::S3::Client.new(
      region: Rails.application.credentials.dig(:aws, :region) || ENV['AWS_REGION'] || 'ap-south-1',
      access_key_id: Rails.application.credentials.dig(:aws, :access_key_id) || ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key) || ENV['AWS_SECRET_ACCESS_KEY']
    )
    @bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET']
  end

  def generate_pdf
    # Ensure invoice has share token
    @invoice.generate_share_token if @invoice.share_token.blank?
    @invoice.save! if @invoice.changed?

    # Generate filename and S3 key
    filename = generate_filename
    s3_key = generate_s3_key

    begin
      # Generate PDF content
      pdf_content = generate_pdf_content

      # Upload to S3 and serve through your domain
      if @s3_client && @bucket_name.present?
        upload_to_s3(s3_key, pdf_content)
        # Use proxy URL instead of direct S3 URL
        public_url = generate_proxy_url(filename)

        {
          success: true,
          filename: filename,
          s3_key: s3_key,
          public_url: public_url,
          storage: 's3',
          message: "PDF generated and uploaded to S3, served via your domain"
        }
      else
        # Fallback to local storage
        file_path = Rails.root.join('public', 'invoices', filename)
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, pdf_content, mode: 'wb')

        {
          success: true,
          file_path: file_path.to_s,
          filename: filename,
          public_url: generate_proxy_url(filename),
          storage: 'local',
          message: "PDF generated successfully locally (S3 not configured)"
        }
      end
    rescue => e
      Rails.logger.error "PDF generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Generate fallback HTML
      begin
        html_filename = filename.gsub('.pdf', '.html')
        html_s3_key = s3_key.gsub('.pdf', '.html')
        html_content = generate_html_content

        if @s3_client && @bucket_name.present?
          upload_to_s3(html_s3_key, html_content, content_type: 'text/html')
          fallback_public_url = generate_s3_https_url(html_s3_key)
        else
          html_path = Rails.root.join('public', 'invoices', html_filename)
          FileUtils.mkdir_p(File.dirname(html_path))
          File.write(html_path, html_content)
          fallback_public_url = generate_local_public_url(html_filename)
        end

        {
          success: false,
          error: e.message,
          fallback_filename: html_filename,
          fallback_public_url: fallback_public_url,
          message: "PDF generation failed, HTML fallback created"
        }
      rescue => html_error
        Rails.logger.error "HTML fallback failed: #{html_error.message}"
        {
          success: false,
          error: e.message,
          message: "Both PDF and HTML generation failed"
        }
      end
    end
  end

  def generate_local_public_url(filename)
    if Rails.env.development?
      host = 'localhost:3002'  # Use development server
      protocol = 'http'
    else
      host = Rails.application.config.action_controller.default_url_options[:host] || 'atmanirbharfarmbangalore.com'
      protocol = 'https'
    end

    "#{protocol}://#{host}/invoices/#{filename}"
  end

  def generate_proxy_url(filename)
    # Use clean URL format: /invoices/123.pdf
    if Rails.env.development?
      host = 'localhost:3002'
      protocol = 'http'
    else
      # Your production domain
      host = 'atmanirbharfarmbangalore.com'
      protocol = 'https'
    end

    # Clean filename format: just invoice ID + .pdf
    clean_filename = "#{@invoice.id}.pdf"
    "#{protocol}://#{host}/invoices/#{clean_filename}"
  end

  def generate_s3_https_url(s3_key)
    # Try CloudFront first for faster delivery
    cloudfront_domain = Rails.application.credentials.dig(:aws, :cloudfront_domain) || ENV['AWS_CLOUDFRONT_DOMAIN']

    if cloudfront_domain.present?
      "https://#{cloudfront_domain}/#{s3_key}"
    else
      # Fallback to S3 direct HTTPS URL
      region = @s3_client.config.region
      "https://#{@bucket_name}.s3.#{region}.amazonaws.com/#{s3_key}"
    end
  end

  def self.cleanup_old_pdfs(days_old = 30)
    # Clean up PDFs older than specified days
    cutoff_date = days_old.days.ago
    invoices_dir = Rails.root.join('public', 'invoices')

    return unless Dir.exist?(invoices_dir)

    Dir.glob(invoices_dir.join('*')).each do |file_path|
      next if File.directory?(file_path)
      next if File.basename(file_path) == '.gitkeep'

      if File.mtime(file_path) < cutoff_date
        File.delete(file_path)
        Rails.logger.info "Cleaned up old PDF: #{File.basename(file_path)}"
      end
    end
  end

  private

  def generate_filename
    # Format: invoice_123_TOKEN.pdf
    "invoice_#{@invoice.id}_#{@invoice.share_token}.pdf"
  end

  def generate_s3_key
    # Simple S3 key that matches our clean URL: invoices/123.pdf
    "invoices/#{@invoice.id}.pdf"
  end

  def upload_to_s3(s3_key, content, content_type: 'application/pdf')
    @s3_client.put_object(
      bucket: @bucket_name,
      key: s3_key,
      body: content,
      content_type: content_type,
      cache_control: 'public, max-age=3600',
      metadata: {
        'invoice-id' => @invoice.id.to_s,
        'customer-id' => @invoice.customer_id.to_s,
        'generated-at' => Time.current.iso8601
      }
    )
  end

  def generate_pdf_content
    # Set up controller context for rendering
    controller = ApplicationController.new
    controller.request = ActionDispatch::Request.new({})
    controller.response = ActionDispatch::Response.new

    # Set instance variables for the template - including delivery assignments for second page
    controller.instance_variable_set(:@invoice, @invoice)
    controller.instance_variable_set(:@invoice_items, @invoice.invoice_items.includes(:product))
    controller.instance_variable_set(:@customer, @invoice.customer)

    # Load delivery assignments for the second page delivery report
    delivery_assignments = @invoice.delivery_assignments.includes(:product).order(:completed_at, :scheduled_date)
    controller.instance_variable_set(:@delivery_assignments, delivery_assignments)

    # Render PDF using WickedPdf with both pages (invoice + delivery report)
    WickedPdf.new.pdf_from_string(
      controller.render_to_string(
        template: 'invoices/show',
        layout: false,
        locals: {
          invoice: @invoice,
          invoice_items: @invoice.invoice_items.includes(:product),
          delivery_assignments: delivery_assignments
        }
      ),
      page_size: 'A4',
      margin: { top: 5, bottom: 5, left: 5, right: 5 },
      encoding: 'UTF-8'
    )
  end

  def generate_html_content
    # Set up controller context for rendering
    controller = ApplicationController.new
    controller.request = ActionDispatch::Request.new({})
    controller.response = ActionDispatch::Response.new

    # Set instance variables for the template - including delivery assignments for second page
    controller.instance_variable_set(:@invoice, @invoice)
    controller.instance_variable_set(:@invoice_items, @invoice.invoice_items.includes(:product))
    controller.instance_variable_set(:@customer, @invoice.customer)

    # Load delivery assignments for the second page delivery report
    delivery_assignments = @invoice.delivery_assignments.includes(:product).order(:completed_at, :scheduled_date)
    controller.instance_variable_set(:@delivery_assignments, delivery_assignments)

    # Render HTML using the PDF template with both pages (invoice + delivery report)
    controller.render_to_string(
      template: 'invoices/show',
      layout: false,
      locals: {
        invoice: @invoice,
        invoice_items: @invoice.invoice_items.includes(:product),
        delivery_assignments: delivery_assignments
      }
    )
  end
end