class ProcurementAssignmentsController < ApplicationController
  before_action :set_procurement_assignment, only: [:show, :edit, :update, :destroy, :complete, :cancel]
  before_action :authenticate_user!

  def index
    @assignments = current_user.procurement_assignments.includes(:procurement_schedule)
    
    # Apply filters
    @assignments = @assignments.for_vendor(params[:vendor]) if params[:vendor].present?
    @assignments = @assignments.where(status: params[:status]) if params[:status].present?
    @assignments = @assignments.for_date(params[:date]) if params[:date].present?
    
    if params[:date_from].present? && params[:date_to].present?
      @assignments = @assignments.for_date_range(params[:date_from], params[:date_to])
    end
    
    @assignments = @assignments.recent.page(params[:page]).per(20)
    
    # Summary data
    @summary = {
      total_assignments: @assignments.count,
      pending_assignments: @assignments.pending.count,
      completed_assignments: @assignments.completed.count,
      overdue_assignments: @assignments.select(&:is_overdue?).count,
      total_planned_quantity: @assignments.sum(:planned_quantity),
      total_actual_quantity: @assignments.sum(:actual_quantity)
    }
    
    # Get unique vendors for filter
    @vendors = current_user.procurement_assignments.distinct.pluck(:vendor_name).compact.sort
  end

  def show
    @schedule = @assignment.procurement_schedule
  end

  def edit
    unless @assignment.can_be_edited?
      redirect_to @assignment, alert: 'This assignment cannot be edited.'
    end
  end

  def update
    if @assignment.update(procurement_assignment_params)
      redirect_to @assignment, notice: 'Procurement assignment was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @assignment.destroy
    redirect_to procurement_assignments_url, notice: 'Procurement assignment was successfully deleted.'
  end

  def complete
    actual_quantity = params[:actual_quantity]&.to_f
    
    if actual_quantity && actual_quantity >= 0
      @assignment.mark_as_completed!(actual_quantity)
      redirect_to @assignment, notice: 'Assignment marked as completed successfully.'
    else
      redirect_to @assignment, alert: 'Please provide a valid actual quantity.'
    end
  end

  def cancel
    @assignment.mark_as_cancelled!
    redirect_to @assignment, notice: 'Assignment cancelled successfully.'
  end

  def bulk_update
    assignment_ids = params[:assignment_ids] || []
    action = params[:bulk_action]
    
    assignments = current_user.procurement_assignments.where(id: assignment_ids)
    
    case action
    when 'complete'
      assignments.each do |assignment|
        if assignment.can_be_edited?
          assignment.mark_as_completed!(assignment.planned_quantity)
        end
      end
      redirect_to procurement_assignments_path, notice: "#{assignments.count} assignments marked as completed."
      
    when 'cancel'
      assignments.each do |assignment|
        if assignment.can_be_edited?
          assignment.mark_as_cancelled!
        end
      end
      redirect_to procurement_assignments_path, notice: "#{assignments.count} assignments cancelled."
      
    else
      redirect_to procurement_assignments_path, alert: 'Invalid bulk action.'
    end
  end

  def calendar
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @assignments = current_user.procurement_assignments.for_date(@date)
    
    # Get assignments for the entire month for calendar display
    start_of_month = @date.beginning_of_month
    end_of_month = @date.end_of_month
    @monthly_assignments = current_user.procurement_assignments
                                      .for_date_range(start_of_month, end_of_month)
                                      .group_by(&:date)
    
    # Daily summary for the selected date
    @daily_summary = {
      total_planned: @assignments.sum(:planned_quantity),
      total_actual: @assignments.sum(:actual_quantity),
      total_cost: @assignments.with_actual_quantity.sum(&:actual_cost),
      total_revenue: @assignments.with_actual_quantity.sum(&:actual_revenue),
      profit: @assignments.with_actual_quantity.sum(&:actual_profit),
      completion_rate: @assignments.empty? ? 0 : (@assignments.completed.count.to_f / @assignments.count * 100).round(2)
    }
  end

  def daily_report
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @assignments = current_user.procurement_assignments.for_date(@date)
    
    @report_data = {
      date: @date,
      assignments: @assignments,
      total_vendors: @assignments.distinct.count(:vendor_name),
      total_planned_quantity: @assignments.sum(:planned_quantity),
      total_actual_quantity: @assignments.sum(:actual_quantity),
      total_planned_cost: @assignments.sum(&:planned_cost),
      total_actual_cost: @assignments.sum(&:actual_cost),
      total_planned_revenue: @assignments.sum(&:planned_revenue),
      total_actual_revenue: @assignments.sum(&:actual_revenue),
      planned_profit: @assignments.sum(&:planned_profit),
      actual_profit: @assignments.sum(&:actual_profit),
      completion_rate: @assignments.empty? ? 0 : (@assignments.completed.count.to_f / @assignments.count * 100).round(2)
    }
    
    # Vendor breakdown
    @vendor_breakdown = @assignments.group_by(&:vendor_name).map do |vendor, vendor_assignments|
      {
        vendor: vendor,
        assignments_count: vendor_assignments.count,
        planned_quantity: vendor_assignments.sum(&:planned_quantity),
        actual_quantity: vendor_assignments.sum { |a| a.actual_quantity || 0 },
        planned_cost: vendor_assignments.sum(&:planned_cost),
        actual_cost: vendor_assignments.sum(&:actual_cost),
        profit: vendor_assignments.sum(&:actual_profit)
      }
    end
  end

  def analytics_data
    date_range = params[:date_range] || 'week'
    start_date, end_date = calculate_date_range(date_range)
    
    assignments = current_user.procurement_assignments.for_date_range(start_date, end_date)
    
    analytics = {
      summary: {
        total_assignments: assignments.count,
        completed_assignments: assignments.completed.count,
        pending_assignments: assignments.pending.count,
        total_vendors: assignments.distinct.count(:vendor_name),
        completion_rate: assignments.completion_rate_for_period(start_date, end_date)
      },
      financial: {
        total_planned_cost: assignments.sum(&:planned_cost),
        total_actual_cost: assignments.sum(&:actual_cost),
        total_planned_revenue: assignments.sum(&:planned_revenue),
        total_actual_revenue: assignments.sum(&:actual_revenue),
        planned_profit: assignments.sum(&:planned_profit),
        actual_profit: assignments.sum(&:actual_profit)
      },
      quantity: {
        total_planned_quantity: assignments.sum(:planned_quantity),
        total_actual_quantity: assignments.sum(:actual_quantity),
        variance: assignments.sum(&:variance_quantity)
      }
    }
    
    render json: analytics
  end

  private

  def set_procurement_assignment
    @assignment = current_user.procurement_assignments.find(params[:id])
  end

  def procurement_assignment_params
    params.require(:procurement_assignment).permit(:actual_quantity, :notes, :status)
  end

  def authenticate_user!
    # Add your authentication logic here
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
      [1.week.ago.to_date, Date.current]
    end
  end
end