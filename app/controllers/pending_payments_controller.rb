class PendingPaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_pending_payment, only: [:show, :edit, :update, :destroy, :mark_as_paid, :mark_as_pending]

  def index
    @pending_payments = current_user.pending_payments.includes(:customer)
                                   .order(created_at: :desc)
                                   .page(params[:page]).per(20)

    # Filter by status if provided
    if params[:status].present?
      @pending_payments = @pending_payments.where(status: params[:status])
    end

    # Search by customer name or month
    if params[:search].present?
      @pending_payments = @pending_payments.joins(:customer)
                                         .where("customers.name ILIKE ? OR pending_payments.month ILIKE ?",
                                               "%#{params[:search]}%", "%#{params[:search]}%")
    end

    @total_pending_amount = current_user.pending_payments.pending.sum(:amount)
    @total_paid_amount = current_user.pending_payments.paid.sum(:amount)
  end

  def show
  end

  def new
    @pending_payment = current_user.pending_payments.build
    @customers = current_user.customers.active.order(:name)
  end

  def create
    @pending_payment = current_user.pending_payments.build(pending_payment_params)

    if @pending_payment.save
      redirect_to pending_payments_path, notice: 'Pending payment was successfully created.'
    else
      @customers = current_user.customers.active.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @customers = current_user.customers.active.order(:name)
  end

  def update
    if @pending_payment.update(pending_payment_params)
      redirect_to pending_payments_path, notice: 'Pending payment was successfully updated.'
    else
      @customers = current_user.customers.active.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pending_payment.destroy
    redirect_to pending_payments_path, notice: 'Pending payment was successfully deleted.'
  end

  def mark_as_paid
    if @pending_payment.mark_as_paid!
      redirect_to pending_payments_path, notice: 'Payment marked as paid successfully.'
    else
      redirect_to pending_payments_path, alert: 'Failed to mark payment as paid.'
    end
  end

  def mark_as_pending
    if @pending_payment.mark_as_pending!
      redirect_to pending_payments_path, notice: 'Payment marked as pending successfully.'
    else
      redirect_to pending_payments_path, alert: 'Failed to mark payment as pending.'
    end
  end

  def search_customers
    # Accept both 'q' and 'search' parameters for debugging
    search_term = (params[:q] || params[:search]).to_s.strip

    Rails.logger.info "🔍 Search customers called with params: #{params.inspect}"
    Rails.logger.info "🔍 Search term: '#{search_term}'"

    if search_term.blank?
      Rails.logger.info "🔍 Search term is blank, returning empty array"
      render json: []
      return
    end

    customers = current_user.customers.active
                           .where("name ILIKE ?", "%#{search_term}%")
                           .limit(10)
                           .pluck(:id, :name, :phone_number, :member_id)

    Rails.logger.info "🔍 Found #{customers.length} customers"

    result = customers.map { |c|
      text = "#{c[1]} - #{c[2]}"
      text += " (#{c[3]})" if c[3].present?
      { id: c[0], text: text }
    }

    Rails.logger.info "🔍 Returning JSON: #{result.inspect}"
    render json: result
  end

  def total_pending_amount
    amount = current_user.pending_payments.pending.sum(:amount)
    render json: { total_pending_amount: amount }
  end

  private

  def set_pending_payment
    @pending_payment = current_user.pending_payments.find(params[:id])
  end

  def pending_payment_params
    params.require(:pending_payment).permit(:customer_id, :month, :year, :amount, :status, :notes)
  end

  def authenticate_user!
    redirect_to login_path unless current_user
  end
end