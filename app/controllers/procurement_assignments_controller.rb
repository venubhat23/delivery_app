class ProcurementAssignmentsController < ApplicationController
  before_action :set_procurement_assignment, only: [:show, :edit, :update, :destroy, :complete, :cancel]
  before_action :authenticate_user!
  
  def new
    @assignment = ProcurementAssignment.new
    @assignment.date = params[:date] ? Date.parse(params[:date]) : Date.current
  end
  
  def create
    @assignment = current_user.procurement_assignments.build(create_procurement_assignment_params)
    
    # Set default procurement_schedule_id if not provided
    unless @assignment.procurement_schedule_id
      schedule = current_user.procurement_schedules.first_or_create!(
        vendor_name: @assignment.vendor_name || "Default Vendor",
        from_date: @assignment.date || Date.current,
        to_date: @assignment.date || Date.current,
        quantity: @assignment.planned_quantity || 1,
        buying_price: @assignment.buying_price || 0,
        selling_price: @assignment.selling_price || 0,
        unit: @assignment.unit || "liters",
        product_id: @assignment.product_id,
        status: "active"
      )
      @assignment.procurement_schedule_id = schedule.id
    end
    
    respond_to do |format|
      if @assignment.save
        format.html { redirect_to calendar_view_milk_analytics_path, notice: 'Procurement assignment was successfully created.' }
        format.json { render json: @assignment, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @assignment.errors, status: :unprocessable_entity }
      end
    end
  end

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
    
    respond_to do |format|
      format.html
      format.json { render json: @assignment }
    end
  end

  def edit
    unless @assignment.can_be_edited?
      error_message = if @assignment.date < Date.current
                       'Cannot edit assignments from past dates.'
                     elsif !%w[pending completed].include?(@assignment.status)
                       'Cannot edit assignments with status: ' + @assignment.status
                     else
                       'This assignment cannot be edited.'
                     end

      respond_to do |format|
        format.html { redirect_to @assignment, alert: error_message }
        format.json { render json: { error: error_message }, status: :unprocessable_entity }
      end
      return
    end

    respond_to do |format|
      format.html
      format.json {
        render json: {
          success: true,
          assignment: {
            id: @assignment.id,
            date: @assignment.date.strftime('%Y-%m-%d'),
            vendor_name: @assignment.vendor_name,
            planned_quantity: @assignment.planned_quantity,
            actual_quantity: @assignment.actual_quantity,
            buying_price: @assignment.buying_price,
            selling_price: @assignment.selling_price,
            unit: @assignment.unit,
            status: @assignment.status,
            notes: @assignment.notes,
            product_id: @assignment.product_id,
            product_name: @assignment.product&.name
          }
        }
      }
    end
  end

  def update
    respond_to do |format|
      if @assignment.update(update_procurement_assignment_params)
        format.html { redirect_to calendar_view_milk_analytics_path, notice: 'Procurement assignment was successfully updated.' }
        format.json { render json: { success: true, assignment: @assignment, message: 'Assignment updated successfully!' } }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json {
          Rails.logger.error "Procurement assignment update failed: #{@assignment.errors.full_messages.join(', ')}"
          render json: @assignment.errors, status: :unprocessable_entity
        }
      end
    end
  end

  def destroy
    respond_to do |format|
      begin
        @assignment.destroy
        format.html { redirect_to calendar_view_milk_analytics_path, notice: 'Procurement assignment was successfully deleted.' }
        format.json {
          render json: {
            success: true,
            message: 'Procurement assignment was successfully deleted.',
            assignment_id: params[:id]
          }
        }
      rescue => e
        format.html { redirect_to calendar_view_milk_analytics_path, alert: "Error deleting assignment: #{e.message}" }
        format.json { render json: { success: false, message: "Error deleting assignment: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  def complete
    actual_quantity = params[:actual_quantity]&.to_f || @assignment.planned_quantity

    respond_to do |format|
      begin
        if actual_quantity && actual_quantity >= 0
          @assignment.update!(
            status: 'completed',
            actual_quantity: actual_quantity,
            updated_at: Time.current
          )

          format.html { redirect_to @assignment, notice: 'Assignment marked as completed successfully.' }
          format.json {
            render json: {
              success: true,
              message: 'Assignment marked as completed successfully.',
              assignment: {
                id: @assignment.id,
                status: @assignment.status,
                actual_quantity: @assignment.actual_quantity
              }
            }
          }
        else
          format.html { redirect_to @assignment, alert: 'Please provide a valid actual quantity.' }
          format.json { render json: { success: false, message: 'Please provide a valid actual quantity.' }, status: :unprocessable_entity }
        end
      rescue => e
        format.html { redirect_to @assignment, alert: "Error completing assignment: #{e.message}" }
        format.json { render json: { success: false, message: "Error completing assignment: #{e.message}" }, status: :unprocessable_entity }
      end
    end
  end

  def cancel
    @assignment.mark_as_cancelled!
    redirect_to @assignment, notice: 'Assignment cancelled successfully.'
  end

  def complete_till_today
    vendor_name = params[:vendor_name]

    if vendor_name.blank?
      respond_to do |format|
        format.json { render json: { success: false, message: 'Vendor name is required' }, status: :bad_request }
      end
      return
    end

    # Find all pending assignments for this vendor till today
    assignments_to_complete = ProcurementAssignment.where(
      vendor_name: vendor_name,
      status: 'pending'
    ).where('date <= ?', Date.current)

    completed_count = 0
    failed_count = 0

    assignments_to_complete.find_each do |assignment|
      begin
        # Use planned quantity as actual quantity if not set
        actual_quantity = assignment.actual_quantity.presence || assignment.planned_quantity

        if assignment.update(
          status: 'completed',
          actual_quantity: actual_quantity,
          completed_at: Time.current
        )
          completed_count += 1
        else
          failed_count += 1
          Rails.logger.error "Failed to complete assignment #{assignment.id}: #{assignment.errors.full_messages.join(', ')}"
        end
      rescue => e
        failed_count += 1
        Rails.logger.error "Error completing assignment #{assignment.id}: #{e.message}"
      end
    end

    respond_to do |format|
      if completed_count > 0
        message = "Successfully completed #{completed_count} procurement assignment(s) for #{vendor_name} till today."
        message += " #{failed_count} failed to update." if failed_count > 0

        format.json {
          render json: {
            success: true,
            message: message,
            completed_count: completed_count,
            failed_count: failed_count,
            vendor_name: vendor_name
          }
        }
      else
        message = failed_count > 0 ?
          "Failed to complete any assignments (#{failed_count} errors occurred)." :
          "No pending assignments found for #{vendor_name} till today."

        format.json {
          render json: {
            success: false,
            message: message,
            completed_count: 0,
            failed_count: failed_count,
            vendor_name: vendor_name
          }
        }
      end
    end
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

  def create_procurement_assignment_params
    params.require(:procurement_assignment).permit(
      :date, :vendor_name, :planned_quantity, :buying_price, :selling_price,
      :actual_quantity, :unit, :status, :procurement_schedule_id, :user_id, :product_id
    )
  end
  
  def update_procurement_assignment_params
    params.require(:procurement_assignment).permit(
      :date, :vendor_name, :planned_quantity, :buying_price, :selling_price,
      :actual_quantity, :unit, :status, :product_id
    )
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