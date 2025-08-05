class ProcurementSchedulesController < ApplicationController
  before_action :set_procurement_schedule, only: [:show, :edit, :update, :destroy, :generate_assignments]
  before_action :authenticate_user!

  def index
    @procurement_schedules = current_user.procurement_schedules.includes(:procurement_assignments)
    
    # Apply filters
    @procurement_schedules = @procurement_schedules.by_vendor(params[:vendor]) if params[:vendor].present?
    @procurement_schedules = @procurement_schedules.where(status: params[:status]) if params[:status].present?
    
    if params[:date_from].present? && params[:date_to].present?
      @procurement_schedules = @procurement_schedules.by_date_range(params[:date_from], params[:date_to])
    end
    
    @procurement_schedules = @procurement_schedules.recent.page(params[:page]).per(10)
    
    # Analytics data for the index page
    @total_schedules = current_user.procurement_schedules.count
    @active_schedules = current_user.procurement_schedules.active.count
    @total_planned_cost = current_user.procurement_schedules.sum(&:total_planned_cost)
    @total_planned_revenue = current_user.procurement_schedules.sum(&:total_planned_revenue)
    
    # Get unique vendors for filter dropdown
    @vendors = current_user.procurement_schedules.distinct.pluck(:vendor_name).compact.sort
  end

  def show
    @assignments = @procurement_schedule.procurement_assignments.by_date
    @analytics = calculate_schedule_analytics(@procurement_schedule)
  end

  def new
    @procurement_schedule = current_user.procurement_schedules.build
  end

  def create
    @procurement_schedule = current_user.procurement_schedules.build(procurement_schedule_params)
    
    if @procurement_schedule.save
      redirect_to @procurement_schedule, notice: 'Procurement schedule was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    unless @procurement_schedule.can_be_edited?
      redirect_to @procurement_schedule, alert: 'This schedule cannot be edited.'
    end
  end

  def update
    if @procurement_schedule.update(procurement_schedule_params)
      redirect_to @procurement_schedule, notice: 'Procurement schedule was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @procurement_schedule.destroy
    redirect_to procurement_schedules_url, notice: 'Procurement schedule was successfully deleted.'
  end

  def analytics
    @date_range = params[:date_range] || 'month'
    @start_date, @end_date = calculate_date_range(@date_range)
    
    # Get procurement data
    procurement_schedules = current_user.procurement_schedules.by_date_range(@start_date, @end_date)
    procurement_assignments = current_user.procurement_assignments.for_date_range(@start_date, @end_date)
    
    # Calculate analytics
    @analytics = {
      total_planned_quantity: procurement_assignments.sum(:planned_quantity),
      total_actual_quantity: procurement_assignments.sum(:actual_quantity),
      total_planned_cost: procurement_assignments.sum('planned_quantity * buying_price'),
      total_actual_cost: procurement_assignments.with_actual_quantity.sum('actual_quantity * buying_price'),
      total_planned_revenue: procurement_assignments.sum('planned_quantity * selling_price'),
      total_actual_revenue: procurement_assignments.with_actual_quantity.sum('actual_quantity * selling_price'),
      completion_rate: procurement_assignments.completion_rate_for_period(@start_date, @end_date)
    }
    
    @analytics[:planned_profit] = @analytics[:total_planned_revenue] - @analytics[:total_planned_cost]
    @analytics[:actual_profit] = @analytics[:total_actual_revenue] - @analytics[:total_actual_cost]
    
    # Chart data
    @daily_data = generate_daily_chart_data(@start_date, @end_date)
    @vendor_data = generate_vendor_chart_data(@start_date, @end_date)
    
    # Integration with delivery data
    @delivery_comparison = calculate_delivery_comparison(@start_date, @end_date)
  end

  def generate_assignments
    if @procurement_schedule.procurement_assignments.exists?
      redirect_to @procurement_schedule, alert: 'Assignments have already been generated for this schedule.'
    else
      @procurement_schedule.send(:generate_procurement_assignments)
      redirect_to @procurement_schedule, notice: 'Procurement assignments generated successfully.'
    end
  end

  private

  def set_procurement_schedule
    @procurement_schedule = current_user.procurement_schedules.find(params[:id])
  end

  def procurement_schedule_params
    params.require(:procurement_schedule).permit(:vendor_name, :from_date, :to_date, :quantity, 
                                                  :buying_price, :selling_price, :status, :unit, :notes)
  end

  def authenticate_user!
    # Add your authentication logic here
    # For now, assuming current_user is available
  end

  def calculate_schedule_analytics(schedule)
    assignments = schedule.procurement_assignments
    
    {
      total_assignments: assignments.count,
      completed_assignments: assignments.completed.count,
      pending_assignments: assignments.pending.count,
      total_planned_quantity: assignments.sum(:planned_quantity),
      total_actual_quantity: assignments.sum(:actual_quantity),
      total_planned_cost: schedule.total_planned_cost,
      total_actual_cost: schedule.actual_total_cost,
      total_planned_revenue: schedule.total_planned_revenue,
      total_actual_revenue: schedule.actual_total_revenue,
      planned_profit: schedule.planned_profit,
      actual_profit: schedule.actual_profit,
      completion_percentage: schedule.completion_percentage,
      profit_margin: schedule.profit_margin_percentage
    }
  end

  def calculate_date_range(range)
    case range
    when 'week'
      [1.week.ago.to_date, Date.current]
    when 'month'
      [1.month.ago.to_date, Date.current]
    when 'quarter'
      [3.months.ago.to_date, Date.current]
    when 'year'
      [1.year.ago.to_date, Date.current]
    else
      [1.month.ago.to_date, Date.current]
    end
  end

  def generate_daily_chart_data(start_date, end_date)
    assignments = current_user.procurement_assignments.for_date_range(start_date, end_date)
    
    (start_date..end_date).map do |date|
      daily_assignments = assignments.for_date(date)
      {
        date: date.strftime('%Y-%m-%d'),
        planned_quantity: daily_assignments.sum(:planned_quantity),
        actual_quantity: daily_assignments.sum(:actual_quantity),
        planned_cost: daily_assignments.sum('planned_quantity * buying_price'),
        actual_cost: daily_assignments.with_actual_quantity.sum('actual_quantity * buying_price')
      }
    end
  end

  def generate_vendor_chart_data(start_date, end_date)
    assignments = current_user.procurement_assignments.for_date_range(start_date, end_date)
    
    assignments.group(:vendor_name).group_by(&:vendor_name).map do |vendor, vendor_assignments|
      {
        vendor: vendor,
        total_quantity: vendor_assignments.sum(&:actual_quantity).to_f,
        total_cost: vendor_assignments.sum(&:actual_cost),
        total_revenue: vendor_assignments.sum(&:actual_revenue),
        profit: vendor_assignments.sum(&:actual_profit)
      }
    end
  end

  def calculate_delivery_comparison(start_date, end_date)
    # Get procurement data
    total_milk_purchased = current_user.procurement_assignments
                                      .for_date_range(start_date, end_date)
                                      .sum(:actual_quantity)
    
    # Get delivery data (assuming milk products)
    total_milk_delivered = current_user.delivery_assignments
                                      .joins(:product)
                                      .where(scheduled_date: start_date..end_date)
                                      .where(products: { name: ['Milk', 'milk'] }) # Adjust based on your product naming
                                      .sum(:quantity)
    
    {
      total_purchased: total_milk_purchased || 0,
      total_delivered: total_milk_delivered || 0,
      remaining_inventory: (total_milk_purchased || 0) - (total_milk_delivered || 0),
      delivery_percentage: total_milk_purchased.to_f > 0 ? (total_milk_delivered.to_f / total_milk_purchased * 100).round(2) : 0
    }
  end
end