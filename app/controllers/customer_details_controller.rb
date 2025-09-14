class CustomerDetailsController < ApplicationController
  before_action :require_login

  def index
    @active_tab = params[:tab] || 'all'

    case @active_tab
    when 'regular'
      @customers = Customer.regular_customers.includes(:delivery_person, :delivery_assignments)
                           .order(:name)
                           .page(params[:page])
                           .per(50)
    when 'interval'
      @customers = Customer.interval_customers.includes(:delivery_person, :delivery_assignments)
                           .order(:name)
                           .page(params[:page])
                           .per(50)
    else # 'all'
      @customers = Customer.all_customers_with_intervals.includes(:delivery_person, :delivery_assignments)
                           .order(:name)
                           .page(params[:page])
                           .per(50)
    end

    # Statistics for display
    @stats = {
      regular_count: Customer.regular_customers.count,
      interval_count: Customer.interval_customers.count,
      total_count: Customer.all_customers_with_intervals.count
    }
  end
end
