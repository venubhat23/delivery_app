
# app/jobs/monthly_invoice_generation_job.rb
class MonthlyInvoiceGenerationJob < ApplicationJob
  queue_as :default

  def perform(month = Date.current.beginning_of_month)
    generated_invoices = Invoice.generate_monthly_invoices(month)
    
    Rails.logger.info "Generated #{generated_invoices.count} monthly invoices for #{month.strftime('%B %Y')}"
    
    # Send notification to admin about generated invoices
    if generated_invoices.any?
      AdminMailer.monthly_invoices_generated(generated_invoices, month).deliver_now
    end
  rescue => e
    Rails.logger.error "Failed to generate monthly invoices for #{month.strftime('%B %Y')}: #{e.message}"
  end
end
