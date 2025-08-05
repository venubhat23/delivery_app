class ProcurementAssignmentsController < ApplicationController
  before_action :set_procurement_assignment, only: [:show, :edit, :update, :destroy, :complete, :cancel]
  before_action :set_date_filters, only: [:index, :calendar]
  
  def index
    @procurement_assignments = ProcurementAssignment.joins(:procurement_schedule)
                                                    .where(procurement_schedules: { user: current_user })
                                                    .includes(:procurement_schedule)
                                                    .order(date: :desc)
    
    # Apply filters
    @procurement_assignments = @procurement_assignments.for_vendor(params[:vendor]) if params[:vendor].present?
    @procurement_assignments = @procurement_assignments.where(status: params[:status]) if params[:status].present?
    @procurement_assignments = @procurement_assignments.in_date_range(@start_date, @end_date) if @start_date && @end_date
    
    # Pagination
    @procurement_assignments = @procurement_assignments.page(params[:page]).per(25)
    
    # Get unique vendors for filter dropdown
    @vendors = ProcurementAssignment.joins(:procurement_schedule)
                                    .where(procurement_schedules: { user: current_user })
                                    .distinct
                                    .pluck(:vendor_name)
                                    .compact
                                    .sort
    
    # Summary statistics
    @summary_stats = calculate_summary_stats
  end
  
  def calendar
    # Default to current month if no dates specified
    @start_date ||= Date.current.beginning_of_month
    @end_date ||= Date.current.end_of_month
    
    # Get assignments for the calendar period
    @assignments = ProcurementAssignment.joins(:procurement_schedule)
                                        .where(procurement_schedules: { user: current_user })
                                        .in_date_range(@start_date, @end_date)
                                        .includes(:procurement_schedule)
                                        .group_by(&:date)
    
    # Calendar data for JavaScript
    @calendar_data = @assignments.map do |date, assignments|
      {
        date: date,
        assignments: assignments.map do |assignment|
          {
            id: assignment.id,
            vendor: assignment.vendor_name,
            planned_quantity: assignment.planned_quantity,
            actual_quantity: assignment.actual_quantity,
            status: assignment.status,
            profit: assignment.actual_profit
          }
        end,
        total_planned: assignments.sum(&:planned_quantity),
        total_actual: assignments.sum { |a| a.actual_quantity || 0 },
        total_profit: assignments.sum(&:actual_profit)
      }
    end
  end
  
  def show
    @schedule = @procurement_assignment.procurement_schedule
  end
  
  def edit
  end
  
  def update
    if @procurement_assignment.update(procurement_assignment_params)
      redirect_to @procurement_assignment, notice: 'Procurement assignment was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @procurement_assignment.destroy
    redirect_to procurement_assignments_url, notice: 'Procurement assignment was successfully deleted.'
  end
  
  def complete
    actual_quantity = params[:actual_quantity].to_f
    notes = params[:notes]
    
    if actual_quantity > 0
      @procurement_assignment.mark_as_completed!(actual_quantity, notes)
      render json: { success: true, message: 'Assignment marked as completed successfully.' }
    else
      render json: { success: false, message: 'Actual quantity must be greater than 0.' }
    end
  rescue => e
    render json: { success: false, message: e.message }
  end
  
  def cancel
    reason = params[:reason]
    
    @procurement_assignment.mark_as_cancelled!(reason)
    render json: { success: true, message: 'Assignment cancelled successfully.' }
  rescue => e
    render json: { success: false, message: e.message }
  end
  
  def bulk_complete
    assignment_ids = params[:assignment_ids] || []
    success_count = 0
    error_count = 0
    errors = []
    
    assignment_ids.each do |id|
      assignment = current_user.procurement_schedules
                               .joins(:procurement_assignments)
                               .find_by(procurement_assignments: { id: id })
                               &.procurement_assignments
                               &.find(id)
      
      if assignment
        actual_quantity = params["actual_quantity_#{id}"].to_f
        notes = params["notes_#{id}"]
        
        if actual_quantity > 0
          assignment.mark_as_completed!(actual_quantity, notes)
          success_count += 1
        else
          error_count += 1
          errors << "Assignment ##{id}: Actual quantity must be greater than 0"
        end
      else
        error_count += 1
        errors << "Assignment ##{id}: Not found or access denied"
      end
    rescue => e
      error_count += 1
      errors << "Assignment ##{id}: #{e.message}"
    end
    
    if success_count > 0
      message = "#{success_count} assignment(s) completed successfully."
      message += " #{error_count} failed." if error_count > 0
      redirect_to procurement_assignments_path, notice: message
    else
      redirect_to procurement_assignments_path, alert: "No assignments were completed. Errors: #{errors.join(', ')}"
    end
  end
  
  def bulk_cancel
    assignment_ids = params[:assignment_ids] || []
    reason = params[:cancel_reason]
    success_count = 0
    
    assignment_ids.each do |id|
      assignment = current_user.procurement_schedules
                               .joins(:procurement_assignments)
                               .find_by(procurement_assignments: { id: id })
                               &.procurement_assignments
                               &.find(id)
      
      if assignment
        assignment.mark_as_cancelled!(reason)
        success_count += 1
      end
    rescue => e
      # Log error but continue processing
      Rails.logger.error "Failed to cancel assignment #{id}: #{e.message}"
    end
    
    redirect_to procurement_assignments_path, notice: "#{success_count} assignment(s) cancelled successfully."
  end
  
  def today
    @today_assignments = ProcurementAssignment.joins(:procurement_schedule)
                                              .where(procurement_schedules: { user: current_user })
                                              .for_date(Date.current)
                                              .includes(:procurement_schedule)
                                              .order(:vendor_name)
    
    @summary = {
      total: @today_assignments.count,
      completed: @today_assignments.where(status: 'completed').count,
      pending: @today_assignments.where(status: 'pending').count,
      cancelled: @today_assignments.where(status: 'cancelled').count,
      total_planned: @today_assignments.sum(:planned_quantity),
      total_actual: @today_assignments.sum(:actual_quantity),
      total_planned_cost: @today_assignments.sum('planned_quantity * buying_price'),
      total_actual_cost: @today_assignments.sum('actual_quantity * buying_price')
    }
  end
  
  def overdue
    @overdue_assignments = ProcurementAssignment.joins(:procurement_schedule)
                                                .where(procurement_schedules: { user: current_user })
                                                .where(status: 'pending')
                                                .where('date < ?', Date.current)
                                                .includes(:procurement_schedule)
                                                .order(date: :asc)
    
    @overdue_count = @overdue_assignments.count
    @total_overdue_quantity = @overdue_assignments.sum(:planned_quantity)
    @total_overdue_cost = @overdue_assignments.sum('planned_quantity * buying_price')
  end
  
  private
  
  def set_procurement_assignment
    @procurement_assignment = ProcurementAssignment.joins(:procurement_schedule)
                                                   .where(procurement_schedules: { user: current_user })
                                                   .find(params[:id])
  end
  
  def set_date_filters
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
  rescue Date::Error
    @start_date = @end_date = nil
  end
  
  def procurement_assignment_params
    params.require(:procurement_assignment).permit(:actual_quantity, :notes, :status)
  end
  
  def calculate_summary_stats
    assignments = ProcurementAssignment.joins(:procurement_schedule)
                                       .where(procurement_schedules: { user: current_user })
    
    # Apply same filters as main query
    assignments = assignments.for_vendor(params[:vendor]) if params[:vendor].present?
    assignments = assignments.where(status: params[:status]) if params[:status].present?
    assignments = assignments.in_date_range(@start_date, @end_date) if @start_date && @end_date
    
    {
      total_assignments: assignments.count,
      completed_assignments: assignments.where(status: 'completed').count,
      pending_assignments: assignments.where(status: 'pending').count,
      cancelled_assignments: assignments.where(status: 'cancelled').count,
      total_planned_quantity: assignments.sum(:planned_quantity),
      total_actual_quantity: assignments.where(status: 'completed').sum(:actual_quantity),
      total_planned_cost: assignments.sum('planned_quantity * buying_price'),
      total_actual_cost: assignments.where(status: 'completed').sum('actual_quantity * buying_price'),
      total_actual_revenue: assignments.where(status: 'completed').sum('actual_quantity * selling_price'),
      completion_rate: assignments.count > 0 ? ((assignments.where(status: 'completed').count.to_f / assignments.count) * 100).round(2) : 0
    }
  end
end