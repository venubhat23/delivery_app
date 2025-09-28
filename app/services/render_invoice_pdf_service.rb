class RenderInvoicePdfService
  require 'wicked_pdf'

  def initialize
    @base_url = Rails.application.credentials.render_app_url ||
                ENV['RENDER_EXTERNAL_URL'] ||
                "https://#{ENV['RENDER_SERVICE_NAME']}.onrender.com"
  end

  def generate_and_store_pdf(invoice)
    begin
      # Generate PDF content
      pdf_content = generate_pdf_content(invoice)

      # Create filename with timestamp to avoid conflicts
      filename = "invoice_#{invoice.id}_#{Time.current.to_i}.pdf"

      # Store PDF in public directory
      pdf_path = store_pdf_file(filename, pdf_content)

      # Return public URL
      public_url = "#{@base_url}/invoices/pdf/#{filename}"

      Rails.logger.info "PDF generated and stored: #{public_url}"

      {
        success: true,
        pdf_url: public_url,
        local_path: pdf_path,
        filename: filename
      }
    rescue => e
      Rails.logger.error "PDF generation failed for invoice #{invoice.id}: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  def cleanup_old_pdfs(days_old = 7)
    # Clean up PDFs older than specified days
    pdf_dir = Rails.root.join('public', 'invoices', 'pdf')
    return unless File.directory?(pdf_dir)

    cutoff_time = days_old.days.ago

    Dir.glob(File.join(pdf_dir, '*.pdf')).each do |file_path|
      if File.mtime(file_path) < cutoff_time
        File.delete(file_path)
        Rails.logger.info "Cleaned up old PDF: #{File.basename(file_path)}"
      end
    end
  end

  def delete_pdf(filename)
    pdf_path = Rails.root.join('public', 'invoices', 'pdf', filename)

    if File.exist?(pdf_path)
      File.delete(pdf_path)
      Rails.logger.info "Deleted PDF: #{filename}"
      true
    else
      false
    end
  end

  private

  def generate_pdf_content(invoice)
    # Use WickedPDF to generate PDF from HTML template
    html_content = ApplicationController.new.render_to_string(
      template: 'invoices/pdf_template',
      locals: { invoice: invoice },
      layout: 'pdf'
    )

    WickedPdf.new.pdf_from_string(
      html_content,
      pdf_options
    )
  end

  def pdf_options
    {
      page_size: 'A4',
      margin: {
        top: 15,
        bottom: 15,
        left: 10,
        right: 10
      },
      encoding: 'UTF-8',
      dpi: 300,
      print_media_type: true,
      disable_smart_shrinking: true,
      zoom: 1.0,
      orientation: 'Portrait'
    }
  end

  def store_pdf_file(filename, pdf_content)
    # Ensure directory exists
    pdf_dir = Rails.root.join('public', 'invoices', 'pdf')
    FileUtils.mkdir_p(pdf_dir) unless File.directory?(pdf_dir)

    # Full file path
    file_path = File.join(pdf_dir, filename)

    # Write PDF content to file
    File.open(file_path, 'wb') do |file|
      file.write(pdf_content)
    end

    # Set proper permissions
    File.chmod(0644, file_path)

    file_path
  end

  def self.get_pdf_url(invoice_id, filename = nil)
    base_url = Rails.application.credentials.render_app_url ||
               ENV['RENDER_EXTERNAL_URL'] ||
               "https://#{ENV['RENDER_SERVICE_NAME']}.onrender.com"

    if filename
      "#{base_url}/invoices/pdf/#{filename}"
    else
      # Try to find existing PDF for this invoice
      pdf_dir = Rails.root.join('public', 'invoices', 'pdf')
      pattern = "invoice_#{invoice_id}_*.pdf"

      if File.directory?(pdf_dir)
        matching_files = Dir.glob(File.join(pdf_dir, pattern))
        if matching_files.any?
          latest_file = matching_files.max_by { |f| File.mtime(f) }
          filename = File.basename(latest_file)
          "#{base_url}/invoices/pdf/#{filename}"
        end
      end
    end
  end
end