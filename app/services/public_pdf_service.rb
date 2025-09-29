# app/services/public_pdf_service.rb
class PublicPdfService
  def self.generate_invoice_pdf(invoice)
    new(invoice).generate_pdf
  end

  def initialize(invoice)
    @invoice = invoice
  end

  def generate_pdf
    # Ensure invoice has share token
    @invoice.generate_share_token if @invoice.share_token.blank?
    @invoice.save! if @invoice.changed?

    # Generate filename
    filename = generate_filename

    # Full file path
    file_path = Rails.root.join('public', 'invoices', filename)

    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(file_path))

    begin
      # Generate PDF content
      pdf_content = generate_pdf_content

      # Write to public folder
      File.write(file_path, pdf_content, mode: 'wb')

      # Return public URL
      {
        success: true,
        file_path: file_path.to_s,
        filename: filename,
        public_url: generate_public_url(filename),
        message: "PDF generated successfully at #{filename}"
      }
    rescue => e
      Rails.logger.error "PDF generation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Generate fallback HTML file
      html_filename = filename.gsub('.pdf', '.html')
      html_path = Rails.root.join('public', 'invoices', html_filename)

      begin
        html_content = generate_html_content
        File.write(html_path, html_content)

        {
          success: false,
          error: e.message,
          fallback_file_path: html_path.to_s,
          fallback_filename: html_filename,
          fallback_public_url: generate_public_url(html_filename),
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

  def generate_public_url(filename)
    if Rails.env.development?
      host = 'localhost:3002'  # Use development server
      protocol = 'http'
    else
      host = Rails.application.config.action_controller.default_url_options[:host] || 'atmanirbharfarmbangalore.com'
      protocol = 'https'
    end

    "#{protocol}://#{host}/invoices/#{filename}"
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

  def generate_pdf_content
    # Set up controller context for rendering
    controller = ApplicationController.new
    controller.request = ActionDispatch::Request.new({})
    controller.response = ActionDispatch::Response.new

    # Set instance variables for the template
    controller.instance_variable_set(:@invoice, @invoice)
    controller.instance_variable_set(:@invoice_items, @invoice.invoice_items.includes(:product))
    controller.instance_variable_set(:@customer, @invoice.customer)

    # Render PDF using WickedPdf
    WickedPdf.new.pdf_from_string(
      controller.render_to_string(
        template: 'invoices/show',
        layout: false,
        locals: { invoice: @invoice }
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

    # Set instance variables for the template
    controller.instance_variable_set(:@invoice, @invoice)
    controller.instance_variable_set(:@invoice_items, @invoice.invoice_items.includes(:product))
    controller.instance_variable_set(:@customer, @invoice.customer)

    # Render HTML using the PDF template
    controller.render_to_string(
      template: 'invoices/pdf_template',
      layout: false,
      locals: { invoice: @invoice }
    )
  end
end