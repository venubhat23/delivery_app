# API Error Handling Configuration
# This ensures all API requests return JSON responses

Rails.application.configure do
  # Handle routing errors with JSON for API requests
  config.exceptions_app = ->(env) {
    request = ActionDispatch::Request.new(env)
    
    # Check if it's an API request
    if request.path.start_with?('/api/')
      error_message = if request.path.include?('/deliveries/') && request.path.include?('/compl')
        "The requested delivery endpoint does not exist. Use 'complete' instead of 'compl'."
      else
        "The requested API endpoint does not exist"
      end
      
      [404, { 'Content-Type' => 'application/json' }, [{ error: 'Not Found', message: error_message }.to_json]]
    else
      # Default Rails error handling for non-API requests
      ActionDispatch::PublicExceptions.new(Rails.public_path).call(env)
    end
  }
end

# Override the default error handling for API controllers
module ApiErrorHandling
  extend ActiveSupport::Concern
  
  included do
    rescue_from ActionController::RoutingError do |exception|
      render json: { 
        error: "Not found", 
        message: "The requested API endpoint does not exist" 
      }, status: :not_found
    end
    
    rescue_from ActionController::UnknownFormat do |exception|
      render json: { 
        error: "Unsupported format", 
        message: "This API only supports JSON format" 
      }, status: :not_acceptable
    end
    
    rescue_from StandardError do |exception|
      Rails.logger.error "API Error: #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n")
      
      render json: { 
        error: "Internal server error", 
        message: Rails.env.development? ? exception.message : "Something went wrong" 
      }, status: :internal_server_error
    end
  end
end