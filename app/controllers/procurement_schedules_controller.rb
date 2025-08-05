class ProcurementSchedulesController < ApplicationController
  before_action :set_procurement_schedule, only: [:show, :edit, :update, :destroy]
  before_action :set_date_filters, only: [:index, :analytics]
  
  def index
    @procurement_schedules = ProcurementSchedule.includes(:user, :procurement_assignments)
                                                .where(user: current_user)
                                                .order(created_at: :desc)
    
    # Apply filters
    @procurement_schedules = @procurement_schedules.by_vendor(params[:vendor]) if params[:vendor].present?
    @procurement_schedules = @procurement_schedules.where(status: params[:status]) if params[:status].present?
    @procurement_schedules = @procurement_schedules.in_date_range(@start_date, @end_date) if @start_date && @end_date
    
    # Pagination
    @procurement_schedules = @procurement_schedules.page(params[:page]).per(20)
    
    # Get unique vendors for filter dropdown
    @vendors = ProcurementSchedule.where(user: current_user).distinct.pluck(:vendor_name).compact.sort
    
    # Summary statistics
    @total_schedules = @procurement_schedules.total_count
    @active_schedules = ProcurementSchedule.where(user: current_user, status: 'active').count
    @total_planned_quantity = @procurement_schedules.sum(&:total_planned_quantity)
    @total_planned_cost = @procurement_schedules.sum(&:total_planned_cost)
  end
  
  def analytics
    # Date range for analytics (default to current month)
    @start_date ||= Date.current.beginning_of_month
    @end_date ||= Date.current.end_of_month
    
    # Key Performance Indicators
    @kpis = calculate_kpis(@start_date, @end_date)
    
    # Chart data
    @daily_procurement_data = get_daily_procurement_data(@start_date, @end_date)
    @vendor_comparison_data = get_vendor_comparison_data(@start_date, @end_date)
    @profit_analysis_data = get_profit_analysis_data(@start_date, @end_date)
    
    # Delivery comparison data
    @delivery_comparison = get_delivery_comparison_data(@start_date, @end_date)
    
    # Recent activities
    @recent_assignments = ProcurementAssignment.joins(:procurement_schedule)
                                               .where(procurement_schedules: { user: current_user })
                                               .includes(:procurement_schedule)
                                               .order(date: :desc)
                                               .limit(10)
    
    # Overdue assignments
    @overdue_assignments = ProcurementAssignment.joins(:procurement_schedule)
                                                .where(procurement_schedules: { user: current_user })
                                                .where(status: 'pending')
                                                .where('date < ?', Date.current)
                                                .includes(:procurement_schedule)
                                                .order(date: :asc)
  end
  
  def show
    @assignments = @procurement_schedule.procurement_assignments.order(:date)
    @completion_stats = {
      total: @assignments.count,
      completed: @assignments.where(status: 'completed').count,
      pending: @assignments.where(status: 'pending').count,
      cancelled: @assignments.where(status: 'cancelled').count
    }
  end
  
  def new
    @procurement_schedule = current_user.procurement_schedules.build
    @procurement_schedule.from_date = Date.current
    @procurement_schedule.to_date = Date.current.end_of_month
    @procurement_schedule.unit = 'liters'
    @procurement_schedule.status = 'active'
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
  
  # AJAX endpoint for vendor suggestions
  def vendor_suggestions
    vendors = ProcurementSchedule.where(user: current_user)
                                 .where('vendor_name ILIKE ?', "%#{params[:q]}%")
                                 .distinct
                                 .pluck(:vendor_name)
                                 .first(10)
    
    render json: vendors
  end
  
  private
  
  def set_procurement_schedule
    @procurement_schedule = current_user.procurement_schedules.find(params[:id])
  end
  
  def set_date_filters
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
  rescue Date::Error
    @start_date = @end_date = nil
  end
  
  def procurement_schedule_params
    params.require(:procurement_schedule).permit(:vendor_name, :from_date, :to_date, 
                                                  :quantity, :buying_price, :selling_price, 
                                                  :status, :notes, :unit)
  end
  
  def calculate_kpis(start_date, end_date)
    user_schedules = ProcurementSchedule.where(user: current_user)
    user_assignments = ProcurementAssignment.joins(:procurement_schedule)
                                            .where(procurement_schedules: { user: current_user })
    
    {
      total_planned_quantity: user_assignments.in_date_range(start_date, end_date).sum(:planned_quantity),
      total_actual_quantity: user_assignments.completed.in_date_range(start_date, end_date).sum(:actual_quantity),
      total_planned_cost: user_assignments.in_date_range(start_date, end_date).sum('planned_quantity * buying_price'),
      total_actual_cost: user_assignments.completed.in_date_range(start_date, end_date).sum('actual_quantity * buying_price'),
      total_actual_revenue: user_assignments.completed.in_date_range(start_date, end_date).sum('actual_quantity * selling_price'),
      completion_rate: user_assignments.completion_rate_for_period(start_date, end_date),
      active_vendors: user_schedules.in_date_range(start_date, end_date).distinct.count(:vendor_name)
    }
  end
  
  def get_daily_procurement_data(start_date, end_date)
    ProcurementAssignment.joins(:procurement_schedule)
                         .where(procurement_schedules: { user: current_user })
                         .completed
                         .in_date_range(start_date, end_date)
                         .group('DATE(date)')
                         .group(:vendor_name)
                         .sum(:actual_quantity)
  end
  
  def get_vendor_comparison_data(start_date, end_date)
    ProcurementAssignment.joins(:procurement_schedule)
                         .where(procurement_schedules: { user: current_user })
                         .completed
                         .in_date_range(start_date, end_date)
                         .group(:vendor_name)
                         .sum(:actual_quantity)
  end
  
  def get_profit_analysis_data(start_date, end_date)
    assignments = ProcurementAssignment.joins(:procurement_schedule)
                                       .where(procurement_schedules: { user: current_user })
                                       .completed
                                       .in_date_range(start_date, end_date)
    
    {
      total_cost: assignments.sum('actual_quantity * buying_price'),
      total_revenue: assignments.sum('actual_quantity * selling_price'),
      by_vendor: assignments.group(:vendor_name)
                           .select('vendor_name, SUM(actual_quantity * buying_price) as cost, SUM(actual_quantity * selling_price) as revenue')
                           .map { |a| { vendor: a.vendor_name, cost: a.cost, revenue: a.revenue, profit: a.revenue - a.cost } }
    }
  end
  
  def get_delivery_comparison_data(start_date, end_date)
    # Get milk purchased data
    milk_purchased = ProcurementAssignment.joins(:procurement_schedule)
                                          .where(procurement_schedules: { user: current_user })
                                          .completed
                                          .in_date_range(start_date, end_date)
                                          .sum(:actual_quantity)
    
    # Get milk delivered data (assuming delivery_assignments track milk deliveries)
    # You might need to adjust this based on your delivery system
    milk_delivered = DeliveryAssignment.where(user: current_user)
                                       .where(scheduled_date: start_date..end_date)
                                       .where(status: 'completed')
                                       .sum(:quantity)
    
    {
      purchased: milk_purchased,
      delivered: milk_delivered,
      remaining: milk_purchased - milk_delivered,
      delivery_percentage: milk_purchased > 0 ? ((milk_delivered / milk_purchased) * 100).round(2) : 0
    }
  end
end