require 'jwt'

class JsonWebToken
  SECRET_KEY = Rails.application.credentials.secret_key_base || Rails.application.secret_key_base

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def self.decode(token)
    return nil if token.blank?

    decoded = JWT.decode(token, SECRET_KEY)[0]
    HashWithIndifferentAccess.new decoded
  rescue JWT::DecodeError, JWT::VerificationError, JWT::InvalidSegmentEncoding, JWT::IncorrectAlgorithm, StandardError => e
    raise ExceptionHandler::InvalidToken, e.message
  end
end