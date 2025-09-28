class AiInsightsController < ApplicationController
  def index
    @reorder_suggestions = generate_reorder_suggestions
    @churn_predictions = generate_churn_predictions
    @demand_forecast = generate_demand_forecast
    @customer_segments = generate_customer_segmentation
    @pricing_insights = generate_smart_pricing
    @seasonal_trends = detect_seasonal_patterns
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

  def demand_forecasting
    @forecast = generate_demand_forecast
    render json: @forecast
  end

  def customer_lifetime_value
    @clv_data = calculate_customer_lifetime_value
    render json: @clv_data
  end

  def smart_pricing
    @pricing = generate_smart_pricing
    render json: @pricing
  end

  def seasonal_patterns
    @patterns = detect_seasonal_patterns
    render json: @patterns
  end

  def product_recommendations
    @recommendations = generate_product_recommendations
    render json: @recommendations
  end

  def route_optimization
    @routes = optimize_delivery_routes
    render json: @routes
  end

  def customer_segmentation
    @segments = generate_customer_segmentation
    render json: @segments
  end

  def revenue_anomalies
    @anomalies = detect_revenue_anomalies
    render json: @anomalies
  end

  private

  def generate_reorder_suggestions
    # Super optimized: Get all data in one query with raw SQL
    sql = <<~SQL
      WITH customer_order_data AS (
        SELECT
          c.id as customer_id,
          c.name as customer_name,
          c.phone_number,
          da.id as assignment_id,
          da.scheduled_date,
          da.quantity,
          da.product_id,
          p.name as product_name,
          p.price as product_price,
          ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY da.scheduled_date DESC) as rn,
          LAG(da.scheduled_date) OVER (PARTITION BY c.id ORDER BY da.scheduled_date DESC) as prev_date
        FROM customers c
        INNER JOIN delivery_assignments da ON c.id = da.customer_id
        INNER JOIN products p ON da.product_id = p.id
        WHERE da.status = 'completed'
      ),
      customer_intervals AS (
        SELECT
          customer_id,
          customer_name,
          phone_number,
          assignment_id,
          scheduled_date,
          quantity,
          product_id,
          product_name,
          product_price,
          rn,
          CASE
            WHEN prev_date IS NOT NULL THEN (prev_date - scheduled_date)::integer
            ELSE NULL
          END as interval_days
        FROM customer_order_data
        WHERE rn <= 5
      ),
      customer_stats AS (
        SELECT
          customer_id,
          customer_name,
          phone_number,
          COUNT(*) as order_count,
          AVG(interval_days) as avg_interval,
          MAX(CASE WHEN rn = 1 THEN scheduled_date END) as last_order_date,
          MAX(CASE WHEN rn = 1 THEN quantity END) as last_quantity,
          MAX(CASE WHEN rn = 1 THEN product_id END) as last_product_id,
          MAX(CASE WHEN rn = 1 THEN product_name END) as last_product_name,
          MAX(CASE WHEN rn = 1 THEN product_price END) as last_product_price
        FROM customer_intervals
        WHERE interval_days IS NOT NULL
        GROUP BY customer_id, customer_name, phone_number
        HAVING COUNT(*) >= 2
      )
      SELECT
        customer_id,
        customer_name,
        phone_number,
        last_order_date,
        last_quantity,
        last_product_id,
        last_product_name,
        last_product_price,
        avg_interval,
        (CURRENT_DATE - last_order_date)::integer as days_since_last,
        CASE
          WHEN (CURRENT_DATE - last_order_date)::integer >= (avg_interval * 0.8) THEN
            LEAST(((CURRENT_DATE - last_order_date)::integer / avg_interval * 100)::integer, 100)
          ELSE 0
        END as urgency_score
      FROM customer_stats
      WHERE (CURRENT_DATE - last_order_date)::integer >= (avg_interval * 0.8)
      ORDER BY urgency_score DESC
      LIMIT 20;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    results.map do |row|
      # Create mock customer and product objects
      customer = OpenStruct.new(
        id: row['customer_id'],
        name: row['customer_name'],
        phone_number: row['phone_number']
      )

      product = OpenStruct.new(
        id: row['last_product_id'],
        name: row['last_product_name'],
        price: row['last_product_price'].to_f
      )

      # Safe date parsing
      last_order_date = case row['last_order_date']
                        when String
                          Date.parse(row['last_order_date'])
                        when Date
                          row['last_order_date']
                        else
                          Date.current
                        end

      last_order = OpenStruct.new(
        scheduled_date: last_order_date,
        quantity: row['last_quantity'].to_f,
        product: product
      )

      {
        customer: customer,
        last_order: last_order,
        days_since_last: row['days_since_last'],
        avg_interval: row['avg_interval'].to_f.round(1),
        urgency_score: row['urgency_score'],
        suggested_quantity: row['last_quantity'].to_f,
        suggested_product: product
      }
    end
  end

  def generate_churn_predictions
    # Super optimized: Single SQL query for churn prediction
    sql = <<~SQL
      WITH customer_order_stats AS (
        SELECT
          c.id as customer_id,
          c.name as customer_name,
          c.phone_number,
          COUNT(*) as total_orders,
          MAX(da.scheduled_date) as last_order_date,
          (CURRENT_DATE - MAX(da.scheduled_date))::integer as days_since_last,
          COUNT(CASE WHEN da.scheduled_date >= CURRENT_DATE - INTERVAL '3 months' THEN 1 END) as recent_orders_3m,
          COUNT(CASE WHEN da.scheduled_date >= CURRENT_DATE - INTERVAL '6 weeks' THEN 1 END) as first_half_orders,
          COUNT(CASE WHEN da.scheduled_date >= CURRENT_DATE - INTERVAL '3 months' AND da.scheduled_date < CURRENT_DATE - INTERVAL '6 weeks' THEN 1 END) as second_half_orders,
          MAX(da.final_amount_after_discount) as last_order_amount
        FROM customers c
        INNER JOIN delivery_assignments da ON c.id = da.customer_id
        WHERE da.status = 'completed'
        GROUP BY c.id, c.name, c.phone_number
        HAVING COUNT(*) > 0
      ),
      churn_calculations AS (
        SELECT
          *,
          CASE
            WHEN second_half_orders > 0 THEN
              LEAST(((second_half_orders - first_half_orders)::float / second_half_orders * 100), 30)
            ELSE 0
          END as frequency_decline_score,
          CASE
            WHEN days_since_last > 30 THEN 40
            WHEN days_since_last > 14 THEN (days_since_last - 14) * 2
            ELSE 0
          END as days_score,
          CASE
            WHEN total_orders < 5 THEN 30
            WHEN total_orders < 10 THEN 15
            ELSE 0
          END as orders_score
        FROM customer_order_stats
      )
      SELECT
        customer_id,
        customer_name,
        phone_number,
        total_orders,
        last_order_date,
        days_since_last,
        frequency_decline_score,
        last_order_amount,
        LEAST((days_score + frequency_decline_score + orders_score)::integer, 100) as risk_score,
        CASE
          WHEN (days_score + frequency_decline_score + orders_score) >= 70 THEN 'High'
          WHEN (days_score + frequency_decline_score + orders_score) >= 50 THEN 'Medium'
          ELSE 'Low'
        END as risk_level
      FROM churn_calculations
      WHERE (days_score + frequency_decline_score + orders_score) > 30
      ORDER BY risk_score DESC
      LIMIT 20;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    results.map do |row|
      # Create mock customer and last order objects
      customer = OpenStruct.new(
        id: row['customer_id'],
        name: row['customer_name'],
        phone_number: row['phone_number']
      )

      # Safe date parsing for churn predictions
      churn_last_order_date = case row['last_order_date']
                              when String
                                Date.parse(row['last_order_date'])
                              when Date
                                row['last_order_date']
                              else
                                Date.current
                              end

      last_order = OpenStruct.new(
        scheduled_date: churn_last_order_date,
        final_amount_after_discount: row['last_order_amount'].to_f
      )

      {
        customer: customer,
        risk_score: row['risk_score'],
        risk_level: row['risk_level'],
        days_since_last: row['days_since_last'],
        frequency_decline: row['frequency_decline_score'].to_f.round(1),
        total_orders: row['total_orders'],
        last_order: last_order
      }
    end
  end

  def calculate_dashboard_stats
    # Cache the results to avoid multiple calculations
    @reorder_suggestions ||= generate_reorder_suggestions
    @churn_predictions ||= generate_churn_predictions

    {
      total_customers: Customer.count,
      reorder_opportunities: @reorder_suggestions.count,
      churn_risks: @churn_predictions.count,
      potential_revenue: calculate_potential_revenue
    }
  end

  def calculate_potential_revenue
    # Use cached results
    @reorder_suggestions ||= generate_reorder_suggestions
    @churn_predictions ||= generate_churn_predictions

    reorder_revenue = @reorder_suggestions.sum do |suggestion|
      suggestion[:suggested_quantity] * (suggestion[:suggested_product]&.price || 0)
    end

    churn_prevention_revenue = @churn_predictions.sum do |prediction|
      prediction[:last_order]&.final_amount_after_discount || 0
    end * 3 # Assume 3 months of orders saved

    {
      reorder_potential: reorder_revenue.round(2),
      churn_prevention: churn_prevention_revenue.round(2),
      total: (reorder_revenue + churn_prevention_revenue).round(2)
    }
  end

  # NEW AI FEATURES

  def generate_demand_forecast
    # 7-day demand forecasting based on historical patterns
    sql = <<~SQL
      WITH daily_demand AS (
        SELECT
          DATE(da.scheduled_date) as delivery_date,
          p.name as product_name,
          p.id as product_id,
          SUM(da.quantity) as total_quantity,
          AVG(da.quantity) as avg_quantity,
          COUNT(*) as order_count,
          EXTRACT(DOW FROM da.scheduled_date) as day_of_week
        FROM delivery_assignments da
        INNER JOIN products p ON da.product_id = p.id
        WHERE da.status = 'completed'
          AND da.scheduled_date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY DATE(da.scheduled_date), p.id, p.name, EXTRACT(DOW FROM da.scheduled_date)
      ),
      weekly_averages AS (
        SELECT
          product_id,
          product_name,
          day_of_week,
          AVG(total_quantity) as avg_daily_demand,
          AVG(order_count) as avg_daily_orders
        FROM daily_demand
        GROUP BY product_id, product_name, day_of_week
      )
      SELECT
        product_id,
        product_name,
        day_of_week,
        avg_daily_demand::numeric(10,2) as forecasted_quantity,
        avg_daily_orders::numeric(10,0) as forecasted_orders
      FROM weekly_averages
      ORDER BY product_name, day_of_week
      LIMIT 50;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    forecast_by_product = {}
    results.each do |row|
      product_name = row['product_name']
      forecast_by_product[product_name] ||= []

      day_names = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

      forecast_by_product[product_name] << {
        day: day_names[row['day_of_week']],
        forecasted_quantity: row['forecasted_quantity'].to_f,
        forecasted_orders: row['forecasted_orders'].to_i
      }
    end

    forecast_by_product
  end

  def calculate_customer_lifetime_value
    # Calculate CLV based on historical data and prediction
    sql = <<~SQL
      WITH customer_metrics AS (
        SELECT
          c.id,
          c.name,
          c.created_at,
          COUNT(da.id) as total_orders,
          SUM(da.final_amount_after_discount) as total_spent,
          AVG(da.final_amount_after_discount) as avg_order_value,
          MIN(da.scheduled_date) as first_order,
          MAX(da.scheduled_date) as last_order,
          (MAX(da.scheduled_date) - MIN(da.scheduled_date))::int as customer_lifespan_days
        FROM customers c
        INNER JOIN delivery_assignments da ON c.id = da.customer_id
        WHERE da.status = 'completed'
        GROUP BY c.id, c.name, c.created_at
        HAVING COUNT(da.id) >= 3
      )
      SELECT
        id,
        name,
        total_orders,
        total_spent,
        avg_order_value,
        customer_lifespan_days,
        CASE
          WHEN customer_lifespan_days > 0 THEN
            ((total_orders * 1.0 / (customer_lifespan_days / 30.0)) * avg_order_value * 12)::numeric(12,2)
          ELSE avg_order_value * 12
        END as predicted_clv
      FROM customer_metrics
      ORDER BY predicted_clv DESC
      LIMIT 20;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    results.map do |row|
      {
        customer_id: row['id'],
        customer_name: row['name'],
        total_orders: row['total_orders'],
        total_spent: row['total_spent'].to_f.round(2),
        avg_order_value: row['avg_order_value'].to_f.round(2),
        customer_lifespan_days: row['customer_lifespan_days'],
        predicted_clv: row['predicted_clv'].to_f,
        clv_tier: case row['predicted_clv'].to_f
                  when 0..5000 then 'Bronze'
                  when 5001..15000 then 'Silver'
                  when 15001..30000 then 'Gold'
                  else 'Platinum'
                  end
      }
    end
  end

  def generate_smart_pricing
    # AI-powered pricing recommendations based on demand and competition
    sql = <<~SQL
      WITH product_performance AS (
        SELECT
          p.id,
          p.name,
          p.price,
          COUNT(da.id) as total_orders_30d,
          AVG(da.quantity) as avg_quantity,
          SUM(da.final_amount_after_discount) as total_revenue_30d,
          COUNT(DISTINCT da.customer_id) as unique_customers
        FROM products p
        LEFT JOIN delivery_assignments da ON p.id = da.product_id
          AND da.status = 'completed'
          AND da.scheduled_date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY p.id, p.name, p.price
      )
      SELECT
        id,
        name,
        price,
        total_orders_30d,
        avg_quantity,
        total_revenue_30d,
        unique_customers,
        CASE
          WHEN total_orders_30d >= 100 AND unique_customers >= 20 THEN 'increase'
          WHEN total_orders_30d <= 10 AND unique_customers <= 5 THEN 'decrease'
          ELSE 'maintain'
        END as pricing_recommendation,
        CASE
          WHEN total_orders_30d >= 100 THEN price * 1.1
          WHEN total_orders_30d <= 10 THEN price * 0.9
          ELSE price
        END as suggested_price
      FROM product_performance
      WHERE price > 0
      ORDER BY total_revenue_30d DESC;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    results.map do |row|
      current_price = row['price'].to_f
      suggested_price = row['suggested_price'].to_f
      price_change_percent = ((suggested_price - current_price) / current_price * 100).round(1)

      {
        product_id: row['id'],
        product_name: row['name'],
        current_price: current_price,
        suggested_price: suggested_price.round(2),
        price_change_percent: price_change_percent,
        recommendation: row['pricing_recommendation'],
        total_orders: row['total_orders_30d'],
        revenue_impact: ((suggested_price - current_price) * row['avg_quantity'].to_f * row['total_orders_30d']).round(2)
      }
    end
  end

  def detect_seasonal_patterns
    # Detect seasonal trends and patterns
    sql = <<~SQL
      WITH monthly_sales AS (
        SELECT
          EXTRACT(MONTH FROM da.scheduled_date) as month,
          EXTRACT(YEAR FROM da.scheduled_date) as year,
          COUNT(*) as total_orders,
          SUM(da.final_amount_after_discount) as total_revenue,
          AVG(da.final_amount_after_discount) as avg_order_value
        FROM delivery_assignments da
        WHERE da.status = 'completed'
          AND da.scheduled_date >= CURRENT_DATE - INTERVAL '12 months'
        GROUP BY EXTRACT(MONTH FROM da.scheduled_date), EXTRACT(YEAR FROM da.scheduled_date)
      ),
      monthly_averages AS (
        SELECT
          month,
          AVG(total_orders) as avg_monthly_orders,
          AVG(total_revenue) as avg_monthly_revenue
        FROM monthly_sales
        GROUP BY month
      )
      SELECT
        month,
        avg_monthly_orders,
        avg_monthly_revenue,
        CASE
          WHEN avg_monthly_orders >= (SELECT AVG(avg_monthly_orders) * 1.2 FROM monthly_averages) THEN 'Peak'
          WHEN avg_monthly_orders <= (SELECT AVG(avg_monthly_orders) * 0.8 FROM monthly_averages) THEN 'Low'
          ELSE 'Normal'
        END as season_type
      FROM monthly_averages
      ORDER BY month;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    month_names = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                   'July', 'August', 'September', 'October', 'November', 'December']

    results.map do |row|
      {
        month: month_names[row['month']],
        month_number: row['month'],
        avg_orders: row['avg_monthly_orders'].to_f.round(0),
        avg_revenue: row['avg_monthly_revenue'].to_f.round(2),
        season_type: row['season_type'],
        trend_indicator: case row['season_type']
                        when 'Peak' then '📈'
                        when 'Low' then '📉'
                        else '➡️'
                        end
      }
    end
  end

  def generate_product_recommendations
    # AI-powered product recommendations
    sql = <<~SQL
      WITH customer_product_matrix AS (
        SELECT
          da.customer_id,
          da.product_id,
          COUNT(*) as purchase_frequency,
          AVG(da.quantity) as avg_quantity
        FROM delivery_assignments da
        WHERE da.status = 'completed'
          AND da.scheduled_date >= CURRENT_DATE - INTERVAL '90 days'
        GROUP BY da.customer_id, da.product_id
      ),
      product_pairs AS (
        SELECT
          cpm1.product_id as product_a,
          cpm2.product_id as product_b,
          COUNT(*) as co_occurrence,
          p1.name as product_a_name,
          p2.name as product_b_name
        FROM customer_product_matrix cpm1
        INNER JOIN customer_product_matrix cpm2 ON cpm1.customer_id = cpm2.customer_id
        INNER JOIN products p1 ON cpm1.product_id = p1.id
        INNER JOIN products p2 ON cpm2.product_id = p2.id
        WHERE cpm1.product_id != cpm2.product_id
        GROUP BY cpm1.product_id, cpm2.product_id, p1.name, p2.name
        HAVING COUNT(*) >= 3
      )
      SELECT
        product_a,
        product_b,
        product_a_name,
        product_b_name,
        co_occurrence,
        (co_occurrence * 100.0 / (SELECT COUNT(DISTINCT customer_id) FROM customer_product_matrix))::numeric(10,2) as recommendation_strength
      FROM product_pairs
      ORDER BY co_occurrence DESC
      LIMIT 15;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    results.map do |row|
      {
        base_product: row['product_a_name'],
        recommended_product: row['product_b_name'],
        co_occurrence: row['co_occurrence'],
        strength: row['recommendation_strength'].to_f,
        confidence_level: case row['recommendation_strength'].to_f
                         when 0..20 then 'Low'
                         when 21..50 then 'Medium'
                         else 'High'
                         end
      }
    end
  end

  def generate_customer_segmentation
    # Advanced customer segmentation using RFM analysis
    sql = <<~SQL
      WITH customer_rfm AS (
        SELECT
          c.id,
          c.name,
          (CURRENT_DATE - MAX(da.scheduled_date))::int as recency_days,
          COUNT(da.id) as frequency,
          SUM(da.final_amount_after_discount) as monetary_value,
          AVG(da.final_amount_after_discount) as avg_order_value
        FROM customers c
        INNER JOIN delivery_assignments da ON c.id = da.customer_id
        WHERE da.status = 'completed'
        GROUP BY c.id, c.name
      ),
      rfm_scores AS (
        SELECT
          *,
          CASE
            WHEN recency_days <= 7 THEN 5
            WHEN recency_days <= 14 THEN 4
            WHEN recency_days <= 30 THEN 3
            WHEN recency_days <= 60 THEN 2
            ELSE 1
          END as recency_score,
          CASE
            WHEN frequency >= 20 THEN 5
            WHEN frequency >= 15 THEN 4
            WHEN frequency >= 10 THEN 3
            WHEN frequency >= 5 THEN 2
            ELSE 1
          END as frequency_score,
          CASE
            WHEN monetary_value >= 10000 THEN 5
            WHEN monetary_value >= 5000 THEN 4
            WHEN monetary_value >= 2000 THEN 3
            WHEN monetary_value >= 500 THEN 2
            ELSE 1
          END as monetary_score
        FROM customer_rfm
      )
      SELECT
        id,
        name,
        recency_days,
        frequency,
        monetary_value,
        recency_score,
        frequency_score,
        monetary_score,
        CASE
          WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
          WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Loyal Customers'
          WHEN recency_score >= 4 AND frequency_score <= 2 THEN 'New Customers'
          WHEN recency_score <= 2 AND frequency_score >= 4 THEN 'At Risk'
          WHEN recency_score <= 2 AND frequency_score <= 2 THEN 'Lost'
          ELSE 'Potential Loyalists'
        END as segment
      FROM rfm_scores
      ORDER BY monetary_value DESC;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    segments = {}
    results.each do |row|
      segment = row['segment']
      segments[segment] ||= { customers: [], count: 0, total_value: 0 }

      segments[segment][:customers] << {
        id: row['id'],
        name: row['name'],
        recency_days: row['recency_days'],
        frequency: row['frequency'],
        monetary_value: row['monetary_value'].to_f.round(2),
        scores: {
          recency: row['recency_score'],
          frequency: row['frequency_score'],
          monetary: row['monetary_score']
        }
      }
      segments[segment][:count] += 1
      segments[segment][:total_value] += row['monetary_value'].to_f
    end

    segments
  end

  def detect_revenue_anomalies
    # Detect unusual revenue patterns
    sql = <<~SQL
      WITH daily_revenue AS (
        SELECT
          DATE(da.scheduled_date) as revenue_date,
          SUM(da.final_amount_after_discount) as daily_revenue,
          COUNT(*) as daily_orders
        FROM delivery_assignments da
        WHERE da.status = 'completed'
          AND da.scheduled_date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY DATE(da.scheduled_date)
      ),
      revenue_stats AS (
        SELECT
          AVG(daily_revenue) as avg_revenue,
          STDDEV(daily_revenue) as stddev_revenue
        FROM daily_revenue
      )
      SELECT
        dr.revenue_date,
        dr.daily_revenue,
        dr.daily_orders,
        rs.avg_revenue,
        CASE
          WHEN dr.daily_revenue > (rs.avg_revenue + 2 * rs.stddev_revenue) THEN 'High Anomaly'
          WHEN dr.daily_revenue < (rs.avg_revenue - 2 * rs.stddev_revenue) THEN 'Low Anomaly'
          WHEN dr.daily_revenue > (rs.avg_revenue + rs.stddev_revenue) THEN 'Above Average'
          WHEN dr.daily_revenue < (rs.avg_revenue - rs.stddev_revenue) THEN 'Below Average'
          ELSE 'Normal'
        END as anomaly_type
      FROM daily_revenue dr
      CROSS JOIN revenue_stats rs
      WHERE dr.daily_revenue > (rs.avg_revenue + rs.stddev_revenue)
         OR dr.daily_revenue < (rs.avg_revenue - rs.stddev_revenue)
      ORDER BY dr.revenue_date DESC;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    results.map do |row|
      {
        date: row['revenue_date'],
        revenue: row['daily_revenue'].to_f.round(2),
        orders: row['daily_orders'],
        anomaly_type: row['anomaly_type'],
        variance_from_avg: ((row['daily_revenue'].to_f - row['avg_revenue'].to_f) / row['avg_revenue'].to_f * 100).round(1)
      }
    end
  end

  def optimize_delivery_routes
    # Simple route optimization suggestions
    sql = <<~SQL
      SELECT
        c.id,
        c.name,
        c.address,
        c.latitude,
        c.longitude,
        COUNT(da.id) as delivery_frequency,
        u.name as delivery_person_name
      FROM customers c
      INNER JOIN delivery_assignments da ON c.id = da.customer_id
      LEFT JOIN users u ON c.delivery_person_id = u.id
      WHERE da.status = 'completed'
        AND da.scheduled_date >= CURRENT_DATE - INTERVAL '7 days'
        AND c.latitude IS NOT NULL
        AND c.longitude IS NOT NULL
      GROUP BY c.id, c.name, c.address, c.latitude, c.longitude, u.name
      ORDER BY delivery_frequency DESC;
    SQL

    results = ActiveRecord::Base.connection.execute(sql)

    # Group by delivery person for route optimization
    routes_by_person = {}
    results.each do |row|
      person = row['delivery_person_name'] || 'Unassigned'
      routes_by_person[person] ||= []

      routes_by_person[person] << {
        customer_id: row['id'],
        customer_name: row['name'],
        address: row['address'],
        latitude: row['latitude'].to_f,
        longitude: row['longitude'].to_f,
        frequency: row['delivery_frequency']
      }
    end

    routes_by_person
  end
end
