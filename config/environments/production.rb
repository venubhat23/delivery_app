require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
  config.cache_store = :memory_store
  config.active_job.queue_adapter = :inline

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Configure host for URL generation
  config.action_controller.default_url_options = {
    host: ENV.fetch('DOMAIN_NAME', 'atmanirbharfarmbangalore.com'),
    protocol: 'https'
  }

  # Configure action mailer for production URLs
  config.action_mailer.default_url_options = {
    host: ENV.fetch('DOMAIN_NAME', 'atmanirbharfarmbangalore.com'),
    protocol: 'https'
  }

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Email configuration for Gmail SMTP in production
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'smtp.gmail.com',
    port: 587,
    domain: 'gmail.com',
    user_name: 'atmanirbharfarmbangalore@gmail.com',
    password: ENV['GMAIL_APP_PASSWORD'],
    authentication: 'plain',
    enable_starttls_auto: true
  }

  # Set host to be used by links generated in mailer templates.
  # Use environment variable if available, otherwise default to the main domain
  default_host = ENV.fetch('APP_HOST', 'atmanirbharfarmbangalore.com')
  config.action_mailer.default_url_options = { host: default_host }

  # Set default URL options for the main application routes
  config.action_controller.default_url_options = { host: default_host }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts = [
    "atmanirbharfarmbangalore.com", # Allow requests from main domain
    /.*\.atmanirbharfarm\.work\.gd/, # Allow requests from subdomains
    "delivery-app-ieu2.onrender.com", # Allow requests from Render domain
    /.*\.onrender\.com/,           # Allow requests from all Render domains
    "atmanirbharfarmbangalore.com",
    ENV['APP_HOST']                # Allow requests from environment-specific host
  ].compact
  
  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
