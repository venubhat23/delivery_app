# config/initializers/wicked_pdf.rb

WickedPdf.config = {
  # Path to the wkhtmltopdf executable
  # Leave this blank if wkhtmltopdf is in your PATH
  exe_path: '/usr/local/bin/wkhtmltopdf',
  
  # Global PDF options
  # These will be applied to all PDFs unless overridden
  page_size: 'A4',
  margin: {
    top: 5,    # mm
    bottom: 5,
    left: 5,
    right: 5
  },
  
  # Encoding
  encoding: 'UTF-8',
  
  # Enable local file access (for images, CSS)
  enable_local_file_access: true,
  
  # Disable smart shrinking
  disable_smart_shrinking: true,
  
  # Print media type (use print CSS instead of screen CSS)
  print_media_type: true,
  
  # Additional options
  lowquality: false,
  dpi: 75,
  
  # For debugging - set to true to see HTML instead of PDF
  show_as_html: Rails.env.development? && ENV['DEBUG_PDF'] == 'true'
}

# MIME type registration
Mime::Type.register "application/pdf", :pdf unless Mime::Type.lookup_by_extension(:pdf)