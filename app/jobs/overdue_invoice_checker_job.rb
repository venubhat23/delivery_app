
# app/jobs/overdue_invoice_checker_job.rb
class OverdueInvoiceCheckerJob < ApplicationJob
  queue_as :default

  def perform
    # Mark overdue invoices
    overdue_count = Invoice.mark_overdue_invoices!
    
    # Send reminders for due invoices
    Invoice.send_reminders_for_due_invoices!
    
    Rails.logger.info "Marked #{overdue_count} invoices as overdue and sent due reminders"
  rescue => e
    Rails.logger.error "Failed to check overdue invoices: #{e.message}"
  end
end