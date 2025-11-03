# app/controllers/public_invoices_controller.rb
class PublicInvoicesController < ApplicationController
  # Skip authentication for all actions in this controller
  skip_before_action :require_login
  layout false

  def index
    # Start with optimized base query - include all needed associations
    @invoices = Invoice.includes(:customer, :invoice_items, customer: :delivery_person)

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

    if params[:month].present? && params[:month] != 'all'
      @invoices = @invoices.where(month: params[:month])
    end

    # Apply sorting
    case params[:sort_by]
    when 'amount_high_to_low'
      @invoices = @invoices.order(total_amount: :desc, created_at: :desc)
    when 'amount_low_to_high'
      @invoices = @invoices.order(total_amount: :asc, created_at: :desc)
    when 'date_newest'
      @invoices = @invoices.order(created_at: :desc)
    when 'date_oldest'
      @invoices = @invoices.order(created_at: :asc)
    else
      # Default: sort by highest amount first
      @invoices = @invoices.order(total_amount: :desc, created_at: :desc)
    end

    # Execute query and get results
    @invoices = @invoices.to_a

    # Batch update share tokens for invoices that don't have them
    invoices_without_tokens = @invoices.select { |invoice| invoice.share_token.blank? }
    if invoices_without_tokens.any?
      invoices_without_tokens.each(&:generate_share_token)
      Invoice.transaction do
        invoices_without_tokens.each(&:save!)
      end
    end

    # Cache delivery people list with expiration
    @delivery_people = Rails.cache.fetch("delivery_people_list", expires_in: 30.minutes) do
      User.delivery_people.select(:id, :name, :role).order(:name).to_a
    end

    # Cache total count to avoid repeated queries
    @total_invoice_count = @invoices.size
  end

  def complete
    @invoice = Invoice.find(params[:id])

    if @invoice.update(status: 'completed')
      render json: {
        success: true,
        message: "Invoice ##{@invoice.formatted_number} marked as completed successfully!"
      }
    else
      render json: {
        success: false,
        message: "Failed to complete invoice: #{@invoice.errors.full_messages.join(', ')}"
      }
    end
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: "Invoice not found"
    }, status: :not_found
  end

  def destroy
    @invoice = Invoice.find(params[:id])
    invoice_number = @invoice.formatted_number

    # Delete associated invoice items first
    @invoice.invoice_items.destroy_all

    # Delete the invoice
    @invoice.destroy!

    render json: {
      success: true,
      message: "Invoice ##{invoice_number} and all associated items deleted successfully!"
    }
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: "Invoice not found"
    }, status: :not_found
  rescue => e
    render json: {
      success: false,
      message: "Failed to delete invoice: #{e.message}"
    }, status: :unprocessable_entity
  end
end