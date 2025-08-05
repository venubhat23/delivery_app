class ProcurementAssignmentsController < ApplicationController
  before_action :set_procurement_assignment, only: [:show, :edit, :update, :destroy, :complete, :cancel]

  def index
    @procurement_assignments = ProcurementAssignment.includes(:procurement_schedule, :user)

    # Filter by status
    if params[:status].present?
      @procurement_assignments = @procurement_assignments.where(status: params[:status])
    end

    # Filter by vendor
    if params[:vendor].present?
      @procurement_assignments = @procurement_assignments.by_vendor(params[:vendor])
    end

    # Filter by date range
    if params[:start_date].present? && params[:end_date].present?
      @procurement_assignments = @procurement_assignments.by_date_range(params[:start_date], params[:end_date])
    elsif params[:date].present?
      @procurement_assignments = @procurement_assignments.by_date(params[:date])
    end

    # Calculate summary data before pagination
    filtered_assignments = @procurement_assignments
    @total_assignments = filtered_assignments.count
    @pending_assignments = filtered_assignments.pending.count
    @completed_assignments = filtered_assignments.completed.count
    @overdue_assignments = filtered_assignments.select(&:overdue?).count
    
    # Basic pagination without Kaminari
    page = (params[:page] || 1).to_i
    per_page = 25
    offset = (page - 1) * per_page
    
    @total_count = filtered_assignments.count
    @current_page = page
    @per_page = per_page
    @total_pages = (@total_count.to_f / per_page).ceil
    
    @procurement_assignments = filtered_assignments.order(:date, :vendor_name)
                                                  .limit(per_page)
                                                  .offset(offset)

    # Get unique vendors for filter dropdown
    @vendors = ProcurementAssignment.distinct.pluck(:vendor_name).sort
  end

  def show
  end

  def new
    @procurement_assignment = ProcurementAssignment.new
    @procurement_schedules = ProcurementSchedule.active
  end

  def create
    @procurement_assignment = ProcurementAssignment.new(procurement_assignment_params)
    @procurement_assignment.user = current_user
    @procurement_assignment.status = 'pending' if @procurement_assignment.status.blank?

    if @procurement_assignment.save
      redirect_to procurement_assignments_path, notice: 'Procurement assignment was successfully created.'
    else
      @procurement_schedules = ProcurementSchedule.active
      render :new
    end
  end

  def edit
  end

  def update
    if @procurement_assignment.update(procurement_assignment_params)
      redirect_to @procurement_assignment, notice: 'Procurement assignment was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @procurement_assignment.destroy
    respond_to do |format|
      format.html { redirect_to procurement_assignments_path, notice: 'Procurement assignment was successfully deleted.' }
      format.json { head :no_content }
    end
  rescue => e
    respond_to do |format|
      format.html { redirect_to procurement_assignments_path, alert: 'Failed to delete procurement assignment.' }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def complete
    actual_quantity = params[:actual_quantity]&.to_f
    
    if actual_quantity && actual_quantity > 0
      @procurement_assignment.mark_as_completed!(actual_quantity)
      respond_to do |format|
        format.html { redirect_to procurement_assignments_path, notice: 'Procurement marked as completed successfully!' }
        format.json { render :show, status: :ok, location: @procurement_assignment }
      end
    else
      respond_to do |format|
        format.html { redirect_to procurement_assignments_path, alert: 'Please provide a valid actual quantity.' }
        format.json { render json: @procurement_assignment.errors, status: :unprocessable_entity }
      end
    end
  end

  def cancel
    if @procurement_assignment.cancel!
      redirect_to @procurement_assignment, notice: 'Procurement assignment cancelled.'
    else
      redirect_to @procurement_assignment, alert: 'Failed to cancel procurement assignment.'
    end
  end

  # Bulk actions
  def bulk_complete
    assignment_ids = params[:assignment_ids]
    
    if assignment_ids.present?
      assignments = ProcurementAssignment.where(id: assignment_ids, status: 'pending')
      completed_count = 0
      
      assignments.each do |assignment|
        actual_quantity = params["actual_quantity_#{assignment.id}"]&.to_f
        if actual_quantity && actual_quantity > 0
          assignment.mark_as_completed!(actual_quantity)
          completed_count += 1
        end
      end
      
      message = "Successfully completed #{completed_count} assignments."
      redirect_to procurement_assignments_path, notice: message
    else
      redirect_to procurement_assignments_path, alert: 'No assignments selected.'
    end
  end

  # Daily summary for a specific date
  def daily_summary
    @date = params[:date]&.to_date || Date.current
    @assignments = ProcurementAssignment.by_date(@date).includes(:procurement_schedule, :user)
    
    @summary = {
      total_planned: @assignments.sum(:planned_quantity),
      total_actual: @assignments.completed.sum(:actual_quantity),
      total_cost: @assignments.completed.sum { |a| a.quantity_to_use * a.buying_price },
      total_revenue: @assignments.completed.sum { |a| a.quantity_to_use * a.selling_price },
      vendors_count: @assignments.distinct.count(:vendor_name)
    }
    @summary[:profit] = @summary[:total_revenue] - @summary[:total_cost]
    
    respond_to do |format|
      format.html
      format.json { render json: { date: @date, assignments: @assignments, summary: @summary } }
    end
  end

  # Vendor performance report
  def vendor_performance
    @start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    @end_date = params[:end_date]&.to_date || Date.current.end_of_month
    @vendor = params[:vendor]

    scope = ProcurementAssignment.by_date_range(@start_date, @end_date)
    scope = scope.by_vendor(@vendor) if @vendor.present?

    @vendor_stats = scope.group(:vendor_name).group('DATE(date)').calculate_all(
      :sum,
      planned_quantity: :planned_quantity,
      actual_quantity: :actual_quantity,
      total_cost: 'actual_quantity * buying_price',
      total_revenue: 'actual_quantity * selling_price'
    )

    @vendors = ProcurementAssignment.distinct.pluck(:vendor_name).sort
  end

  private

  def set_procurement_assignment
    @procurement_assignment = ProcurementAssignment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to procurement_assignments_path, alert: 'Procurement assignment not found.'
  end

  def procurement_assignment_params
    params.require(:procurement_assignment).permit(:procurement_schedule_id, :vendor_name, :date, :planned_quantity, :actual_quantity, :buying_price, :selling_price, :unit, :status, :notes)
  end
end