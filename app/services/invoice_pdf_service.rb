# app/services/invoice_pdf_service.rb
class InvoicePdfService
  include Rails.application.routes.url_helpers

  def initialize
    # Configure AWS S3 client
    @s3_client = Aws::S3::Client.new(
      region: Rails.application.credentials.dig(:aws, :region) || ENV['AWS_REGION'],
      access_key_id: Rails.application.credentials.dig(:aws, :access_key_id) || ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key) || ENV['AWS_SECRET_ACCESS_KEY']
    )
    @bucket_name = Rails.application.credentials.dig(:aws, :s3_bucket) || ENV['AWS_S3_BUCKET']
  end

  # Generate and upload PDF to S3, return public URL
  def generate_and_upload_pdf(invoice)
    begin
      # Generate PDF content
      pdf_content = generate_pdf_content(invoice)

      # Upload to S3
      file_key = "invoices/#{invoice.share_token || invoice.id}/invoice_#{invoice.invoice_number}.pdf"

      @s3_client.put_object(
        bucket: @bucket_name,
        key: file_key,
        body: pdf_content,
        content_type: 'application/pdf',
        metadata: {
          'invoice-id' => invoice.id.to_s,
          'customer-id' => invoice.customer_id.to_s,
          'generated-at' => Time.current.iso8601
        }
      )

      # Return CloudFront URL (faster delivery)
      cloudfront_domain = Rails.application.credentials.dig(:aws, :cloudfront_domain) || ENV['AWS_CLOUDFRONT_DOMAIN']

      if cloudfront_domain.present?
        "https://#{cloudfront_domain}/#{file_key}"
      else
        # Fallback to S3 direct URL
        "https://#{@bucket_name}.s3.#{@s3_client.config.region}.amazonaws.com/#{file_key}"
      end

    rescue => e
      Rails.logger.error "Failed to upload PDF to S3: #{e.message}"
      # Fallback to local public URL
      generate_local_public_url(invoice)
    end
  end

  # Option 2: Local temporary file approach (for development/small scale)
  def generate_local_public_url(invoice)
    # Ensure share token exists
    invoice.generate_share_token! unless invoice.share_token.present?

    # Return public URL that doesn't require authentication
    Rails.application.routes.url_helpers.public_invoice_download_url(
      invoice.share_token,
      format: :pdf,
      host: Rails.application.config.action_mailer.default_url_options[:host],
      protocol: Rails.application.config.force_ssl ? 'https' : 'http'
    )
  end

  private

  def generate_pdf_content(invoice)
    # Use your existing PDF generation logic
    controller = InvoicesController.new
    controller.instance_variable_set(:@invoice, invoice)
    controller.instance_variable_set(:@invoice_items, invoice.invoice_items.includes(:product))
    controller.instance_variable_set(:@customer, invoice.customer)

    # Load delivery assignments for the second page delivery report
    delivery_assignments = invoice.delivery_assignments.includes(:product).order(:completed_at, :scheduled_date)
    controller.instance_variable_set(:@delivery_assignments, delivery_assignments)

    # Generate PDF using WickedPDF or your existing PDF generator
    if defined?(WickedPdf)
      WickedPdf.new.pdf_from_string(
        render_invoice_template(invoice),
        page_size: 'A4',
        margin: { top: 10, bottom: 10, left: 10, right: 10 }
      )
    else
      # Fallback method - you can adapt this to your PDF generation approach
      render_pdf_content(invoice)
    end
  end

  def render_invoice_template(invoice)
    # Load delivery assignments for the second page delivery report
    delivery_assignments = invoice.delivery_assignments.includes(:product).order(:completed_at, :scheduled_date)

    ApplicationController.render(
      template: 'invoices/show',
      layout: false,
      assigns: {
        invoice: invoice,
        invoice_items: invoice.invoice_items.includes(:product),
        customer: invoice.customer,
        delivery_assignments: delivery_assignments
      }
    )
  end

  def render_pdf_content(invoice)
    # Load delivery assignments for the second page delivery report
    delivery_assignments = invoice.delivery_assignments.includes(:product).order(:completed_at, :scheduled_date)

    # Simple HTML to PDF conversion if no PDF gem is available
    html_content = ApplicationController.render(
      template: 'invoices/show',
      layout: false,
      assigns: {
        invoice: invoice,
        invoice_items: invoice.invoice_items.includes(:product),
        customer: invoice.customer,
        delivery_assignments: delivery_assignments
      }
    )

    # You might want to use a simple HTML to PDF converter here
    html_content.encode('utf-8')
  end
end