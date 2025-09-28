class AiInsightsController < ApplicationController
  def index
    @reorder_suggestions = generate_reorder_suggestions
    @churn_predictions = generate_churn_predictions
    @dashboard_stats = calculate_dashboard_stats
  end

  def reorder_suggestions
    @suggestions = generate_reorder_suggestions
    render json: @suggestions
  end

  def churn_predictions
    @predictions = generate_churn_predictions
    render json: @predictions
  end

  def send_reorder_notification
    customer = Customer.find(params[:customer_id])
    # Here you would integrate with your notification system
    # For now, we'll just update a flag or log
    Rails.logger.info "Reorder notification sent to customer #{customer.name}"

    render json: { success: true, message: "Reorder notification sent successfully" }
  end

  def send_churn_prevention
    customer = Customer.find(params[:customer_id])
    # Here you would send discount offer or special promotion
    Rails.logger.info "Churn prevention notification sent to customer #{customer.name}"

    render json: { success: true, message: "Churn prevention offer sent successfully" }
  end

  private

  def generate_reorder_suggestions
    suggestions = []

    # Optimized query to get customers with their recent orders
    customers_with_orders = Customer.joins(:delivery_assignments)
                                   .where(delivery_assignments: { status: 'completed' })
                                   .includes(delivery_assignments: [:product])
                                   .distinct

    customers_with_orders.find_each do |customer|
      last_orders = customer.delivery_assignments
                           .where(status: 'completed')
                           .order(scheduled_date: :desc)
                           .limit(5)

      next if last_orders.count < 2

      # Calculate average days between orders
      intervals = []
      last_orders.each_cons(2) do |current, previous|
        intervals << (previous.scheduled_date - current.scheduled_date).to_i
      end

      avg_interval = intervals.sum.to_f / intervals.size
      last_order = last_orders.first
      days_since_last = (Date.current - last_order.scheduled_date).to_i

      # Predict if customer should reorder soon
      reorder_threshold = avg_interval * 0.8

      if days_since_last >= reorder_threshold
        urgency_score = [(days_since_last / avg_interval * 100).round, 100].min

        suggestions << {
          customer: customer,
          last_order: last_order,
          days_since_last: days_since_last,
          avg_interval: avg_interval.round(1),
          urgency_score: urgency_score,
          suggested_quantity: last_order.quantity,
          suggested_product: last_order.product
        }
      end
    end

    suggestions.sort_by { |s| -s[:urgency_score] }.first(20)
  end

  def generate_churn_predictions
    predictions = []

    # Optimized query to get customers with their assignments
    customers_with_orders = Customer.joins(:delivery_assignments)
                                   .where(delivery_assignments: { status: 'completed' })
                                   .includes(:delivery_assignments)
                                   .distinct

    customers_with_orders.find_each do |customer|
      assignments = customer.delivery_assignments
                           .where(status: 'completed')
                           .order(scheduled_date: :desc)

      next if assignments.empty?

      last_order = assignments.first
      days_since_last = (Date.current - last_order.scheduled_date).to_i

      # Calculate order frequency in last 3 months
      recent_orders = assignments.where('scheduled_date >= ?', 3.months.ago)

      if recent_orders.count >= 2
        # Calculate declining trend
        first_half = recent_orders.where('scheduled_date >= ?', 6.weeks.ago).count
        second_half = recent_orders.where('scheduled_date < ?', 6.weeks.ago).count

        frequency_decline = second_half > 0 ? (second_half - first_half).to_f / second_half * 100 : 0
      else
        frequency_decline = 0
      end

      # Calculate churn risk score (0-100)
      risk_score = 0

      # Days since last order factor (0-40 points)
      if days_since_last > 30
        risk_score += 40
      elsif days_since_last > 14
        risk_score += (days_since_last - 14) * 2
      end

      # Frequency decline factor (0-30 points)
      risk_score += [frequency_decline, 30].min

      # Total orders factor (0-30 points)
      total_orders = assignments.count
      if total_orders < 5
        risk_score += 30
      elsif total_orders < 10
        risk_score += 15
      end

      risk_score = [risk_score, 100].min

      if risk_score > 30
        risk_level = if risk_score >= 70
                      'High'
                    elsif risk_score >= 50
                      'Medium'
                    else
                      'Low'
                    end

        predictions << {
          customer: customer,
          risk_score: risk_score.round,
          risk_level: risk_level,
          days_since_last: days_since_last,
          frequency_decline: frequency_decline.round(1),
          total_orders: total_orders,
          last_order: last_order
        }
      end
    end

    predictions.sort_by { |p| -p[:risk_score] }.first(20)
  end

  def calculate_dashboard_stats
    {
      total_customers: Customer.count,
      reorder_opportunities: generate_reorder_suggestions.count,
      churn_risks: generate_churn_predictions.count,
      potential_revenue: calculate_potential_revenue
    }
  end

  def calculate_potential_revenue
    reorder_revenue = generate_reorder_suggestions.sum do |suggestion|
      suggestion[:suggested_quantity] * (suggestion[:suggested_product]&.price || 0)
    end

    churn_prevention_revenue = generate_churn_predictions.sum do |prediction|
      prediction[:last_order]&.final_amount_after_discount || 0
    end * 3 # Assume 3 months of orders saved

    {
      reorder_potential: reorder_revenue.round(2),
      churn_prevention: churn_prevention_revenue.round(2),
      total: (reorder_revenue + churn_prevention_revenue).round(2)
    }
  end
end
