module Api
  module V1
    class BaseController < ActionController::API
      include ExceptionHandler
      include ApiErrorHandling

      before_action :authenticate_request

      attr_reader :current_user, :current_customer

      private

      def authenticate_request
        # Try JWT authentication first (for mobile API compatibility)
        header = request.headers['Authorization']
        header = header.split(' ').last if header

        if header.present?
          begin
            @decoded = JsonWebToken.decode(header)
            if @decoded.present?
              if @decoded[:user_id].present?
                @current_user = User.find(@decoded[:user_id])
              elsif @decoded[:customer_id].present?
                @current_customer = Customer.find(@decoded[:customer_id])
                @current_user = @current_customer  # For compatibility
              end
            else
              render json: { errors: "Token is expired or invalid" }, status: :unauthorized
            end
          rescue ActiveRecord::RecordNotFound => e
            render json: { errors: e.message }, status: :unauthorized
          rescue JWT::DecodeError => e
            render json: { errors: e.message }, status: :unauthorized
          end
        else
          # Fallback to existing customer authorization service
          begin
            @current_customer = CustomerAuthorizationService.call(request.headers).result
            @current_user = @current_customer if @current_customer
          rescue => e
            render json: { errors: "Authentication required" }, status: :unauthorized
          end
        end
      end

      def current_entity
        @current_user || @current_customer
      end
    end
  end
end