class ProcurementSchedulesController < ApplicationController
  before_action :set_procurement_schedule, only: [:show, :edit, :update, :destroy, :generate_assignments, :cancel_schedule]

  def index
    @procurement_schedules = ProcurementSchedule.includes(:user).order(created_at: :desc)
    @total_schedules = @procurement_schedules.count
    @active_schedules = @procurement_schedules.active.count
    @completed_schedules = @procurement_schedules.completed.count
  end

  def show
    @assignments = @procurement_schedule.procurement_assignments.includes(:user).order(:date)
  end

  def new
    @procurement_schedule = ProcurementSchedule.new
    
    # Set default dates
    @procurement_schedule.from_date = Date.current
    @procurement_schedule.to_date = Date.current + 1.month
  end

  def create
    @procurement_schedule = ProcurementSchedule.new(procurement_schedule_params)
    @procurement_schedule.user = current_user
    @procurement_schedule.status = 'active'

    if @procurement_schedule.save
      # Generate daily assignments automatically
      @procurement_schedule.generate_assignments!
      redirect_to @procurement_schedule, notice: 'Procurement schedule was successfully created and assignments generated.'
    else
      render :new
    end
  end

  def edit
  end

  def update
    old_params = {
      from_date: @procurement_schedule.from_date,
      to_date: @procurement_schedule.to_date,
      quantity: @procurement_schedule.quantity
    }

    if @procurement_schedule.update(procurement_schedule_params)
      # Regenerate assignments if date range or quantity changed
      if old_params[:from_date] != @procurement_schedule.from_date ||
         old_params[:to_date] != @procurement_schedule.to_date ||
         old_params[:quantity] != @procurement_schedule.quantity
        
        # Delete existing pending assignments and regenerate
        @procurement_schedule.procurement_assignments.pending.destroy_all
        @procurement_schedule.generate_assignments!
        notice_message = 'Procurement schedule updated and assignments regenerated.'
      else
        notice_message = 'Procurement schedule was successfully updated.'
      end

      redirect_to @procurement_schedule, notice: notice_message
    else
      render :edit
    end
  end

  def destroy
    @procurement_schedule.destroy
    redirect_to procurement_schedules_url, notice: 'Procurement schedule was successfully deleted.'
  end

  def generate_assignments
    if @procurement_schedule.generate_assignments!
      redirect_to @procurement_schedule, notice: 'Assignments generated successfully.'
    else
      redirect_to @procurement_schedule, alert: 'Failed to generate assignments.'
    end
  end

  def cancel_schedule
    @procurement_schedule.cancel!
    redirect_to @procurement_schedule, notice: 'Schedule has been cancelled and all pending assignments have been cancelled.'
  end

  # Analytics dashboard
  def analytics
    @date_range = params[:date_range] || 'this_month'
    @vendor_filter = params[:vendor]

    case @date_range
    when 'today'
      @start_date = Date.current
      @end_date = Date.current
    when 'this_week'
      @start_date = Date.current.beginning_of_week
      @end_date = Date.current.end_of_week
    when 'this_month'
      @start_date = Date.current.beginning_of_month
      @end_date = Date.current.end_of_month
    when 'last_month'
      @start_date = Date.current.last_month.beginning_of_month
      @end_date = Date.current.last_month.end_of_month
    when 'custom'
      @start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
      @end_date = params[:end_date]&.to_date || Date.current.end_of_month
    else
      @start_date = Date.current.beginning_of_month
      @end_date = Date.current.end_of_month
    end

    # Get analytics data
    @total_milk_received = ProcurementAssignment.total_milk_received(@start_date, @end_date)
    @total_cost = ProcurementAssignment.total_cost(@start_date, @end_date)
    @expected_revenue = ProcurementAssignment.expected_revenue(@start_date, @end_date)
    @total_profit = @expected_revenue - @total_cost

    # Vendor-wise data
    @vendor_summary = ProcurementAssignment.completed
                                          .by_date_range(@start_date, @end_date)
                                          .group(:vendor_name)
                                          .group('DATE(date)')
                                          .sum(:actual_quantity)

    # Monthly trends (last 6 months)
    @monthly_trends = []
    6.times do |i|
      month_start = (Date.current - i.months).beginning_of_month
      month_end = month_start.end_of_month
      month_data = {
        month: month_start.strftime('%b %Y'),
        received: ProcurementAssignment.total_milk_received(month_start, month_end),
        cost: ProcurementAssignment.total_cost(month_start, month_end),
        revenue: ProcurementAssignment.expected_revenue(month_start, month_end)
      }
      month_data[:profit] = month_data[:revenue] - month_data[:cost]
      @monthly_trends.unshift(month_data)
    end

    # Top vendors
    @top_vendors = ProcurementAssignment.completed
                                       .by_date_range(@start_date, @end_date)
                                       .group(:vendor_name)
                                       .sum(:actual_quantity)
                                       .sort_by { |_, quantity| -quantity }
                                       .first(10)

    # Recent assignments
    @recent_assignments = ProcurementAssignment.includes(:procurement_schedule, :user)
                                              .by_date_range(@start_date, @end_date)
                                              .order(date: :desc)
                                              .limit(20)

    # Pending assignments
    @pending_assignments = ProcurementAssignment.pending
                                               .includes(:procurement_schedule, :user)
                                               .order(:date)
                                               .limit(10)
  end

  private

  def set_procurement_schedule
    @procurement_schedule = ProcurementSchedule.find(params[:id])
  end

  def procurement_schedule_params
    params.require(:procurement_schedule).permit(:vendor_name, :from_date, :to_date, :quantity, :buying_price, :selling_price, :unit, :notes)
  end
end