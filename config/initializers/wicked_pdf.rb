# config/initializers/wicked_pdf.rb

# Base configuration
base_config = {
  # Path to the wkhtmltopdf executable
  # Leave this blank if wkhtmltopdf is in your PATH
  exe_path: Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf'),

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
  
  # Additional options for production stability
  lowquality: false,
  dpi: 75,
  
  # For debugging - set to true to see HTML instead of PDF
  show_as_html: Rails.env.development? && ENV['DEBUG_PDF'] == 'true'
}

# Production-specific options for headless environments
production_config = {
  # Use Xvfb for headless PDF generation
  use_xvfb: true,
  # Disable JavaScript execution for faster rendering
  disable_javascript: true,
  # Disable external links
  disable_external_links: true,
  # Set timeout to prevent hanging
  javascript_delay: 1000,
  # Additional stability options
  no_stop_slow_scripts: true,
  quiet: true
}

# Merge configurations based on environment
WickedPdf.configure do |config|
  final_config = if Rails.env.production?
    base_config.merge(production_config)
  else
    base_config
  end
  
  final_config.each do |key, value|
    config.send("#{key}=", value)
  end
end

# MIME type registration
Mime::Type.register "application/pdf", :pdf unless Mime::Type.lookup_by_extension(:pdf)