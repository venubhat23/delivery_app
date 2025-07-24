class CustomerAuthorizationService
  def initialize(headers = {})
    @headers = headers
  end

  def self.call(headers)
    new(headers).call
  end

  def call
    OpenStruct.new(result: customer)
  end

  private

  attr_reader :headers

  def customer
    @customer ||= Customer.find(decoded_auth_token[:customer_id]) if decoded_auth_token
  rescue ActiveRecord::RecordNotFound => e
    raise ExceptionHandler::InvalidToken, "#{Message.invalid_token} #{e.message}"
  end

  def decoded_auth_token
    @decoded_auth_token ||= JsonWebToken.decode(http_auth_header)
  end

  def http_auth_header
    if headers['Authorization'].present?
      return headers['Authorization'].split(' ').last
    end
    raise ExceptionHandler::MissingToken, Message.missing_token
  end
end