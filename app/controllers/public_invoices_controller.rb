# app/controllers/public_invoices_controller.rb
class PublicInvoicesController < ApplicationController
  # Skip authentication for all actions in this controller
  skip_before_action :require_login
  layout false

  def index
    # Start with base query
    @invoices = Invoice.includes(:customer, :invoice_items)

    # Apply filters
    if params[:customer_name].present?
      # Use case-insensitive search that works across databases
      search_term = "%#{params[:customer_name].downcase}%"
      @invoices = @invoices.joins(:customer)
                          .where("LOWER(customers.name) LIKE ?", search_term)
    end

    if params[:delivery_person_id].present? && params[:delivery_person_id] != 'all'
      @invoices = @invoices.joins(:customer)
                          .where(customers: { delivery_person_id: params[:delivery_person_id] })
    end

    # Order results (removed limit to show all invoices)
    @invoices = @invoices.order(created_at: :desc)

    # Ensure all invoices have share tokens
    @invoices.each do |invoice|
      if invoice.share_token.blank?
        invoice.generate_share_token
        invoice.save!
      end
    end

    # Load filter options
    @delivery_people = User.delivery_people.order(:name)
  end
end