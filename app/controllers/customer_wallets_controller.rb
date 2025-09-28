class CustomerWalletsController < ApplicationController
  before_action :set_customer, only: [:show, :edit, :update, :add_funds, :deduct_funds]

  def index
    @customers = Customer.order(:name)

    # Apply filters
    @customers = @customers.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?

    # Pagination
    @customers = @customers.page(params[:page]).per(50)

    # Calculate total wallet amount across all customers
    @total_wallet_amount = Customer.sum(:wallet_amount)
  end

  def show
    # Show individual customer wallet details
  end

  def edit
    # Edit customer wallet
  end

  def update
    if @customer.update(customer_params)
      redirect_to customer_wallets_path, notice: 'Customer wallet updated successfully.'
    else
      render :edit
    end
  end

  def add_funds
    amount = params[:amount].to_f

    if amount > 0
      @customer.increment!(:wallet_amount, amount)
      redirect_to customer_wallets_path, notice: "₹#{amount} added to #{@customer.name}'s wallet successfully."
    else
      redirect_to customer_wallets_path, alert: 'Please enter a valid amount.'
    end
  end

  def deduct_funds
    amount = params[:amount].to_f

    if amount > 0 && @customer.wallet_amount >= amount
      @customer.decrement!(:wallet_amount, amount)
      redirect_to customer_wallets_path, notice: "₹#{amount} deducted from #{@customer.name}'s wallet successfully."
    elsif amount <= 0
      redirect_to customer_wallets_path, alert: 'Please enter a valid amount.'
    else
      redirect_to customer_wallets_path, alert: 'Insufficient wallet balance.'
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:wallet_amount)
  end
end