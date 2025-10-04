# app/controllers/public_invoices_controller.rb
class PublicInvoicesController < ApplicationController
  # Skip authentication for all actions in this controller
  skip_before_action :require_login
  layout false

  def index
    # Show all invoices in a simple list format - no filtering, just basic list
    @invoices = Invoice.includes(:customer, :invoice_items)
                      .order(created_at: :desc)
                      .limit(50)  # Show last 50 invoices for performance

    # Ensure all invoices have share tokens
    @invoices.each do |invoice|
      if invoice.share_token.blank?
        invoice.generate_share_token
        invoice.save!
      end
    end
  end
end