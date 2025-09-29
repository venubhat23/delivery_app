# config/initializers/wicked_pdf.rb

# Force clear any existing WickedPdf configuration
if defined?(WickedPdf)
  WickedPdf.instance_variable_set(:@config, nil)
end

# Explicit wkhtmltopdf path detection with fallbacks
def detect_wkhtmltopdf_path
  Rails.logger.info "=== DETECTING WKHTMLTOPDF PATH ==="
  Rails.logger.info "Rails environment: #{Rails.env}"
  Rails.logger.info "Current user: #{`whoami`.strip}"
  Rails.logger.info "HOME: #{ENV['HOME']}"
  
  # Known working paths in order of preference
  candidate_paths = [
    '/usr/bin/wkhtmltopdf',                                    # System package
    '/usr/local/bin/wkhtmltopdf',                             # Manual install
    '/bin/wkhtmltopdf',                                       # Alternative system path
    "#{ENV['HOME']}/.rvm/gems/ruby-#{RUBY_VERSION}/bin/wkhtmltopdf",  # RVM gem
    `which wkhtmltopdf 2>/dev/null`.strip                     # System search
  ].compact.reject(&:empty?)
  
  Rails.logger.info "Checking paths: #{candidate_paths.inspect}"
  
  candidate_paths.each do |path|
    Rails.logger.info "Checking: #{path}"
    if File.exist?(path) && File.executable?(path)
      Rails.logger.info "✓ Found working wkhtmltopdf at: #{path}"
      
      # Test the executable
      begin
        version_output = `#{path} --version 2>&1`.strip
        Rails.logger.info "✓ Version check passed: #{version_output.split("\n").first}"
        return path
      rescue => e
        Rails.logger.warn "✗ Version check failed for #{path}: #{e.message}"
        next
      end
    else
      Rails.logger.info "✗ Not found or not executable: #{path}"
    end
  end
  
  Rails.logger.error "No working wkhtmltopdf found!"
  nil
end

# Detect the correct path
detected_path = detect_wkhtmltopdf_path

# If detection fails, use explicit fallback
if detected_path.nil? || detected_path.empty?
  detected_path = '/usr/bin/wkhtmltopdf'  # Force to system path
  Rails.logger.warn "Using fallback path: #{detected_path}"
end

Rails.logger.info "Final wkhtmltopdf path: #{detected_path}"

# Configure WickedPDF
WickedPdf.configure do |config|
  config.exe_path = detected_path
  config.page_size = 'A4'
  config.margin = { top: 5, bottom: 5, left: 5, right: 5 }
  config.encoding = 'UTF-8'
  config.enable_local_file_access = true
  config.disable_smart_shrinking = true
  config.print_media_type = true
  config.lowquality = false
  config.dpi = 75
  
  # Production specific settings
  if Rails.env.production?
    config.use_xvfb = true
    config.disable_javascript = true
    config.disable_external_links = false  # Allow external assets
    config.javascript_delay = 1000
    config.no_stop_slow_scripts = true
    config.quiet = false  # Enable logging for debugging
    config.load_error_handling = 'ignore'  # Ignore missing assets
    config.disable_plugins = true
    config.disable_internal_links = false
  end
  
  # Debug mode
  config.show_as_html = Rails.env.development? && ENV['DEBUG_PDF'] == 'true'
end

# Final verification
final_path = WickedPdf.config[:exe_path]
Rails.logger.info "=== WICKED PDF CONFIGURED ==="
Rails.logger.info "Final exe_path in config: #{final_path}"
Rails.logger.info "Path exists: #{File.exist?(final_path) if final_path}"
Rails.logger.info "Path executable: #{File.executable?(final_path) if final_path}"
Rails.logger.info "=== END CONFIGURATION ==="

# MIME type registration
Mime::Type.register "application/pdf", :pdf unless Mime::Type.lookup_by_extension(:pdf)