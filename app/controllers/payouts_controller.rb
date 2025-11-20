class PayoutsController < ApplicationController
  before_action :set_payout, only: [:show, :edit, :update, :destroy]

  def index
    @payouts = Payout.all.order(date: :desc, created_at: :desc)

    # Apply date filter if provided
    if params[:from_date].present? && params[:to_date].present?
      @payouts = @payouts.by_date_range(params[:from_date], params[:to_date])
    end

    # Apply payment method filter if provided
    if params[:paid_via].present?
      @payouts = @payouts.where(paid_via: params[:paid_via])
    end

    # Apply payout type filter if provided
    if params[:payout_type].present?
      @payouts = @payouts.by_type(params[:payout_type])
    end

    # Apply payin/payout filter if provided
    if params[:payin_payout].present?
      @payouts = @payouts.by_payin_payout(params[:payin_payout])
    end

    # Search by name or description
    if params[:search].present?
      search_term = "%#{params[:search].downcase}%"
      @payouts = @payouts.where("LOWER(name) LIKE ? OR LOWER(description) LIKE ?", search_term, search_term)
    end

    # Statistics for cards
    @total_payouts = @payouts.count
    @total_amount = @payouts.sum(:amount)
    @cash_payments = @payouts.cash_payments.count
    @non_cash_payments = @payouts.non_cash_payments.count
    @total_payments = @payouts.payments.sum(:amount)
    @total_receipts = @payouts.receipts.sum(:amount)
    @payments_count = @payouts.payments.count
    @receipts_count = @payouts.receipts.count
    @payins_count = @payouts.payins.count
    @payouts_count_only = @payouts.payouts.count

    # Pagination (if needed)
    @payouts = @payouts.page(params[:page]).per(50) if defined?(Kaminari)
  end

  def show
  end

  def new
    @payout = Payout.new(date: Date.current)
  end

  def create
    @payout = Payout.new(payout_params)

    if @payout.save
      redirect_to payouts_path, notice: 'Payout was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @payout.update(payout_params)
      redirect_to payout_path(@payout), notice: 'Payout was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @payout.destroy
    redirect_to payouts_path, notice: 'Payout was successfully deleted.'
  end

  # API endpoints for statistics (can be used in header)
  def statistics
    total_payouts = Payout.count
    total_amount = Payout.sum(:amount)
    cash_payments = Payout.cash_payments.count
    non_cash_payments = Payout.non_cash_payments.count
    total_payments = Payout.payments.sum(:amount)
    total_receipts = Payout.receipts.sum(:amount)
    payments_count = Payout.payments.count
    receipts_count = Payout.receipts.count

    render json: {
      total_payouts: total_payouts,
      total_amount: total_amount,
      cash_payments: cash_payments,
      non_cash_payments: non_cash_payments,
      total_payments: total_payments,
      total_receipts: total_receipts,
      payments_count: payments_count,
      receipts_count: receipts_count,
      formatted_total: "₹#{total_amount.to_f}",
      formatted_payments: "₹#{total_payments.to_f}",
      formatted_receipts: "₹#{total_receipts.to_f}"
    }
  end

  private

  def set_payout
    @payout = Payout.find(params[:id])
  end

  def payout_params
    params.require(:payout).permit(:name, :gst, :amount, :transaction_id, :paid_via, :date, :description, :payout_type, :payin_payout)
  end
end