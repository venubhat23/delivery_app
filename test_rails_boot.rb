#!/usr/bin/env ruby

# Add current directory to load path
$LOAD_PATH.unshift(File.expand_path('.', __dir__))

# Set Rails environment
ENV['RAILS_ENV'] ||= 'development'

# Require Rails application
require_relative 'config/application'

begin
  # Try to initialize the Rails application
  Rails.application.initialize!
  puts "✅ Rails application loaded successfully!"
  puts "Secret key base is set: #{Rails.application.secret_key_base.present?}"
  puts "Environment: #{Rails.env}"
rescue => e
  puts "❌ Error loading Rails application:"
  puts e.message
  puts e.backtrace.first(5)
end