# config/initializers/url_options.rb
# Configure default URL options for all contexts

Rails.application.configure do
  # Set default URL options based on environment
  default_options = case Rails.env
                   when 'production'
                     { host: 'atmanirbharfarmbangalore.com', protocol: 'https' }
                   when 'development'
                     # Use ngrok host for development without port
                     dev_host = ENV.fetch('APP_HOST', 'atmanirbharfarmbangalore.com')
                     if dev_host.include?('ngrok') || dev_host != 'localhost'
                       { host: dev_host, protocol: 'https' }
                     else
                       { host: 'localhost', port: 3000, protocol: 'http' }
                     end
                   when 'test'
                     { host: 'example.com', protocol: 'http' }
                   else
                     { host: 'localhost', port: 3000, protocol: 'http' }
                   end

  # Set for Action Controller
  config.action_controller.default_url_options = default_options
  
  # Set for Action Mailer
  config.action_mailer.default_url_options = default_options
end

# Ensure URL helpers work in console and background jobs
Rails.application.reloader.to_prepare do
  Rails.application.routes.default_url_options = Rails.application.config.action_controller.default_url_options
end