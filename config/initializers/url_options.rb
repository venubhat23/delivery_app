# config/initializers/url_options.rb
# Configure default URL options for all contexts

Rails.application.configure do
  # Set default URL options based on environment
  default_options = case Rails.env
                   when 'production'
                     { host: 'atmanirbharfarm.work.gd', protocol: 'https' }
                   when 'development'
                     { host: 'localhost', port: 3000, protocol: 'http' }
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