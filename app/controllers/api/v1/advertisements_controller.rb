module Api
  module V1
    class AdvertisementsController < BaseController
      # GET /api/v1/advertisements
      def index
        owner_user_id = resolve_owner_user_id
        ads = Advertisement.active.current.order(start_date: :desc)

        render json: ads.as_json(only: [:id, :name, :image_url, :start_date, :end_date, :status, :url])
      end

      private

      def resolve_owner_user_id
        if current_user.is_a?(User)
          current_user.id
        elsif current_user.is_a?(Customer)
          current_user.user_id
        else
          raise ActionController::Unauthorized, 'Unauthorized'
        end
      end
    end
  end
end