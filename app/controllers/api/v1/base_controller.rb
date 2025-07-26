module Api
  module V1
    class BaseController < ActionController::API
      include ExceptionHandler

      before_action :authenticate_request

      private

      def authenticate_request
        @current_customer = CustomerAuthorizationService.call(request.headers).result
      end

      def current_customer
        @current_customer
      end
    end
  end
end