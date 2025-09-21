module Api
  module V1
    class VacationsController < BaseController
      before_action :authenticate_customer!, except: [:complete_ended]
      before_action :authenticate_admin!, only: [:complete_ended]
      before_action :set_vacation, only: [:show, :pause, :unpause, :destroy]
      before_action :check_idempotency_key, only: [:create, :pause, :unpause, :destroy]

      def index
        @vacations = current_customer.user_vacations.includes(:customer)
        
        # Apply filters
        @vacations = @vacations.where(status: params[:status]) if params[:status].present?
        
        if params[:from].present? && params[:to].present?
          from_date = Date.parse(params[:from])
          to_date = Date.parse(params[:to])
          @vacations = @vacations.overlapping_with(from_date, to_date)
        end

        # Simple pagination
        page = [params[:page].to_i, 1].max
        per_page = [params[:per_page].to_i, 20].max
        per_page = [per_page, 100].min # Maximum 100 per page
        
        total_count = @vacations.count
        total_pages = (total_count.to_f / per_page).ceil
        offset = (page - 1) * per_page

        @vacations = @vacations.order(created_at: :desc)
                              .limit(per_page)
                              .offset(offset)

        render json: {
          vacations: @vacations.map(&:as_json),
          pagination: {
            current_page: page,
            per_page: per_page,
            total_pages: total_pages,
            total_count: total_count
          }
        }
      end

      def show
        render json: @vacation.as_json
      end

      def create
        @vacation = current_customer.user_vacations.build(vacation_params)
        @vacation.created_by = current_user&.id

        if should_merge_overlaps?
          merge_overlapping_vacations
        else
          return if check_for_overlaps # Return if overlap detected and rendered
        end

        if @vacation.save
          affected_count = @vacation.send(:skip_assignments)
          
          render json: @vacation.as_json.merge(
            affectedAssignmentsSkipped: affected_count
          ), status: :created
        else
          render_validation_errors(@vacation)
        end
      rescue Date::Error
        render json: { error: 'Invalid date format' }, status: :bad_request
      end

      def pause
        return render_vacation_error('Vacation cannot be paused') unless @vacation.can_be_paused?

        affected_count = 0
        UserVacation.transaction do
          @vacation.pause!
          affected_count = @vacation.send(:reinstate_assignments)
        end

        render json: @vacation.reload.as_json.merge(
          affectedAssignmentsRecreated: affected_count
        )
      rescue StandardError => e
        render json: { error: "Failed to pause vacation: #{e.message}" }, status: :unprocessable_entity
      end

      def unpause
        return render_vacation_error('Vacation cannot be unpaused') unless @vacation.can_be_unpaused?

        affected_count = 0
        UserVacation.transaction do
          @vacation.unpause!
          affected_count = @vacation.send(:skip_assignments)
        end

        render json: @vacation.reload.as_json.merge(
          affectedAssignmentsSkipped: affected_count
        )
      rescue StandardError => e
        render json: { error: "Failed to unpause vacation: #{e.message}" }, status: :unprocessable_entity
      end

      def destroy
        return render_vacation_error('Vacation cannot be cancelled') unless @vacation.can_be_cancelled?

        affected_count = 0
        UserVacation.transaction do
          @vacation.cancel!
          affected_count = @vacation.send(:reinstate_assignments)
        end

        render json: {
          message: 'Vacation cancelled successfully',
          affectedAssignmentsRecreated: affected_count
        }
      rescue StandardError => e
        render json: { error: "Failed to cancel vacation: #{e.message}" }, status: :unprocessable_entity
      end

      def dry_run
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        
        future_range = [start_date, Date.current].max..end_date
        
        assignments_to_skip = current_customer.delivery_assignments
                                              .where(scheduled_date: future_range)
                                              .where(status: ['scheduled', 'pending'])

        assignments_to_recreate = current_customer.delivery_assignments
                                                .where(scheduled_date: future_range)
                                                .where(status: 'skipped_vacation')

        render json: {
          assignmentsToSkip: assignments_to_skip.count,
          assignmentsToRecreate: assignments_to_recreate.count,
          affectedDates: future_range.to_a,
          preview: {
            skipDetails: assignments_to_skip.group(:scheduled_date).count,
            recreateDetails: assignments_to_recreate.group(:scheduled_date).count
          }
        }
      rescue Date::Error
        render json: { error: 'Invalid date format' }, status: :bad_request
      end

      def complete_ended
        # This endpoint can be called by admin users to complete ended vacations
        unless current_user&.admin?
          return render json: { error: 'Unauthorized - Admin access required' }, status: :forbidden
        end

        completed_count = UserVacation.complete_ended_vacations

        render json: {
          message: 'Ended vacations completed successfully',
          completedVacations: completed_count
        }
      rescue StandardError => e
        render json: { error: "Failed to complete ended vacations: #{e.message}" }, status: :internal_server_error
      end

      private

      def set_vacation
        @vacation = current_customer.user_vacations.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Vacation not found' }, status: :not_found
      end

      def vacation_params
        params.permit(:start_date, :end_date, :reason)
      end

      def should_merge_overlaps?
        params[:mergeOverlaps] == 'true' || params[:merge_overlaps] == 'true'
      end

      def check_for_overlaps
        overlapping = current_customer.user_vacations
                                     .active_or_paused
                                     .overlapping_with(@vacation.start_date, @vacation.end_date)

        if overlapping.exists?
          render json: { 
            error: 'Vacation dates overlap with an existing active or paused vacation',
            conflicting_vacations: overlapping.map(&:as_json)
          }, status: :conflict
          return true # Indicate that we rendered a response
        end
        
        false # No overlap found, didn't render
      end

      def merge_overlapping_vacations
        overlapping = current_customer.user_vacations
                                     .active_or_paused
                                     .overlapping_with(@vacation.start_date, @vacation.end_date)

        if overlapping.exists?
          UserVacation.transaction do
            min_start = [*overlapping.pluck(:start_date), @vacation.start_date].min
            max_end = [*overlapping.pluck(:end_date), @vacation.end_date].max
            
            @vacation.start_date = min_start
            @vacation.end_date = max_end
            
            overlapping.destroy_all
          end
        end
      end

      def check_idempotency_key
        return unless request.headers['Idempotency-Key'].present?

        key = request.headers['Idempotency-Key']
        cache_key = "vacation_idempotency:#{current_customer.id}:#{key}"
        
        if Rails.cache.exist?(cache_key)
          cached_response = Rails.cache.read(cache_key)
          render json: cached_response[:body], status: cached_response[:status]
          return
        end

        @idempotency_key = key
      end

      def render_validation_errors(object)
        render json: {
          error: 'Validation failed',
          details: object.errors.full_messages
        }, status: :bad_request
      end

      def render_vacation_error(message)
        render json: { error: message }, status: :unprocessable_entity
      end

      def authenticate_customer!
        token = request.headers['Authorization']&.split(' ')&.last
        return render_unauthorized unless token

        begin
          decoded_token = JsonWebToken.decode(token)
          @current_customer = Customer.find(decoded_token[:customer_id]) if decoded_token[:customer_id]
          @current_user = User.find(decoded_token[:user_id]) if decoded_token[:user_id]
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound
          render_unauthorized
        end

        render_unauthorized unless @current_customer
      end

      def authenticate_admin!
        token = request.headers['Authorization']&.split(' ')&.last
        return render_unauthorized unless token

        begin
          decoded_token = JsonWebToken.decode(token)
          @current_user = User.find(decoded_token[:user_id]) if decoded_token[:user_id]
        rescue JWT::DecodeError, ActiveRecord::RecordNotFound
          render_unauthorized
        end

        render_unauthorized unless @current_user&.admin?
      end

      def current_customer
        @current_customer
      end

      def current_user
        @current_user
      end

      def render_unauthorized
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
    end
  end
end