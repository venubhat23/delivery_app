class AppLaunchMessageJob
  include Sidekiq::Job

  def perform
    Rails.logger.info "Starting App Launch Message Job"

    result = WhatsappLaunchService.send_template_message_to_all_customers

    if result[:success]
      Rails.logger.info "App Launch Messages Job completed successfully"
      Rails.logger.info "Total: #{result[:total_customers]}, Success: #{result[:success_count]}, Errors: #{result[:error_count]}"
    else
      Rails.logger.error "App Launch Messages Job failed: #{result[:error]}"
    end
  end
end