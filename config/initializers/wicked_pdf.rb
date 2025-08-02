# config/initializers/wicked_pdf.rb

# Dynamically detect wkhtmltopdf path
def detect_wkhtmltopdf_path
  # Try common system paths first
  system_paths = [
    '/usr/local/bin/wkhtmltopdf',
    '/usr/bin/wkhtmltopdf',
    '/bin/wkhtmltopdf'
  ]
  
  system_paths.each do |path|
    return path if File.executable?(path)
  end
  
  # Try to find via which command
  which_result = `which wkhtmltopdf 2>/dev/null`.strip
  return which_result unless which_result.empty?
  
  # Try RVM gem paths (common in production with RVM)
  if ENV['HOME']
    # Try current Ruby version
    rvm_paths = [
      "#{ENV['HOME']}/.rvm/gems/ruby-#{RUBY_VERSION}/bin/wkhtmltopdf",
      "#{ENV['HOME']}/.rvm/gems/ruby-#{RUBY_VERSION}@global/bin/wkhtmltopdf"
    ]
    
    rvm_paths.each do |path|
      return path if File.executable?(path)
    end
    
    # Try to find any Ruby version in RVM gems
    rvm_gems_dir = "#{ENV['HOME']}/.rvm/gems"
    if Dir.exist?(rvm_gems_dir)
      Dir.glob("#{rvm_gems_dir}/ruby-*/bin/wkhtmltopdf").each do |path|
        return path if File.executable?(path)
      end
    end
  end
  
  # Try wkhtmltopdf-binary gem path as last resort
  begin
    return Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf')
  rescue Gem::GemNotFoundException
    # Gem not found, continue
  end
  
  # If all else fails, let wicked_pdf try to find it
  nil
end

# Base configuration
base_config = {
  # Path to the wkhtmltopdf executable
  # Dynamically detect the correct path for the current environment
  exe_path: detect_wkhtmltopdf_path,

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

# Use the new configure method instead of deprecated config=
WickedPdf.configure do |config|
  if Rails.env.production?
    base_config.merge(production_config).each do |key, value|
      config.send("#{key}=", value)
    end
  else
    base_config.each do |key, value|
      config.send("#{key}=", value)
    end
  end
end

# Log the detected path for debugging
detected_path = detect_wkhtmltopdf_path
Rails.logger.info "WickedPDF configured with wkhtmltopdf path: #{detected_path || 'auto-detect'}"

# In production, also log some additional debugging info
if Rails.env.production?
  Rails.logger.info "Ruby version: #{RUBY_VERSION}"
  Rails.logger.info "HOME environment: #{ENV['HOME']}"
  Rails.logger.info "PATH environment: #{ENV['PATH']}"
end

# MIME type registration
Mime::Type.register "application/pdf", :pdf unless Mime::Type.lookup_by_extension(:pdf)