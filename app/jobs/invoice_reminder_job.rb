# app/jobs/invoice_reminder_job.rb
class InvoiceReminderJob < ApplicationJob
  queue_as :default

  def perform(invoice)
    return unless invoice.status == 'pending'
    
    # Send email reminder
    InvoiceMailer.payment_reminder(invoice).deliver_now
    
    # Update last reminder sent timestamp
    invoice.update!(last_reminder_sent_at: Time.current)
    
    Rails.logger.info "Payment reminder sent for Invoice ##{invoice.invoice_number}"
  rescue => e
    Rails.logger.error "Failed to send reminder for Invoice ##{invoice.invoice_number}: #{e.message}"
  end
end
