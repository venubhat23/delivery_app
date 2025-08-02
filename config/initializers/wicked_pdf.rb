# config/initializers/wicked_pdf.rb

# Determine the best wkhtmltopdf executable path
def find_wkhtmltopdf_path
  # Try gem-provided binary first (more reliable in containerized environments)
  begin
    gem_path = Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf')
    return gem_path if File.executable?(gem_path)
  rescue Gem::GemNotFoundException
    Rails.logger.warn "wkhtmltopdf-binary gem not found, trying system installation"
  end
  
  # Try common system installation paths
  system_paths = [
    '/usr/local/bin/wkhtmltopdf',
    '/usr/bin/wkhtmltopdf',
    `which wkhtmltopdf`.strip
  ].compact.reject(&:empty?)
  
  system_paths.each do |path|
    return path if File.executable?(path)
  end
  
  # If nothing found, let wicked_pdf try to find it automatically
  Rails.logger.warn "No wkhtmltopdf executable found, letting wicked_pdf auto-detect"
  nil
end

# Base configuration
base_config = {
  # Path to the wkhtmltopdf executable
  exe_path: find_wkhtmltopdf_path,

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
WickedPdf.config = if Rails.env.production?
  base_config.merge(production_config)
else
  base_config
end

# Log the configuration for debugging
Rails.logger.info "WickedPdf configured with exe_path: #{WickedPdf.config[:exe_path] || 'auto-detect'}"

# MIME type registration
Mime::Type.register "application/pdf", :pdf unless Mime::Type.lookup_by_extension(:pdf)