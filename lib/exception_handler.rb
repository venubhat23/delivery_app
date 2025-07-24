module ExceptionHandler
  extend ActiveSupport::Concern

  # Custom error classes
  class AuthenticationError < StandardError; end
  class MissingToken < StandardError; end
  class InvalidToken < StandardError; end

  included do
    # Handle authentication errors
    rescue_from ExceptionHandler::AuthenticationError, with: :unauthorized_request
    rescue_from ExceptionHandler::MissingToken, with: :unauthorized_request
    rescue_from ExceptionHandler::InvalidToken, with: :unauthorized_request
  end

  private

  def unauthorized_request(e)
    render json: { error: e.message }, status: :unauthorized
  end
end