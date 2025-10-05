class WhatsappMessagesController < ApplicationController
  before_action :require_login
  before_action :require_admin

  def index
    # Main page showing WhatsApp message options
  end

  def search_customers
    term = params[:term]
    customers = Customer.active
                      .search(term)
                      .limit(20)
                      .select(:id, :name, :phone_number, :member_id)

    results = customers.map do |customer|
      {
        id: customer.id,
        text: "#{customer.name} - #{customer.phone_number}",
        name: customer.name,
        phone: customer.phone_number,
        member_id: customer.member_id
      }
    end

    render json: { results: results }
  end

  def send_individual_message
    customer_id = params[:customer_id]
    message = params[:message]

    customer = Customer.find_by(id: customer_id)

    if customer.blank?
      render json: { success: false, error: 'Customer not found' }
      return
    end

    if message.blank?
      render json: { success: false, error: 'Message cannot be empty' }
      return
    end

    twilio_service = TwilioWhatsappService.new
    result = twilio_service.send_custom_message(customer.phone_number, message)

    if result
      render json: {
        success: true,
        message: "Message sent successfully to #{customer.name}"
      }
    else
      render json: {
        success: false,
        error: "Failed to send message to #{customer.name}"
      }
    end
  end

  def unpaid_customers_data
    month = params[:month].to_i
    year = params[:year].to_i

    # Set defaults if not provided
    month = Date.current.month if month == 0
    year = Date.current.year if year == 0

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    # Optimized query to prevent N+1 - get all data in one query
    customers_with_unpaid_data = Customer.joins(:invoices)
                                        .where(invoices: {
                                          status: ['pending', 'overdue'],
                                          invoice_date: start_date..end_date
                                        })
                                        .select(
                                          'customers.id',
                                          'customers.name',
                                          'customers.phone_number',
                                          'SUM(invoices.total_amount) AS total_unpaid_amount',
                                          'COUNT(invoices.id) AS unpaid_invoice_count'
                                        )
                                        .group('customers.id, customers.name, customers.phone_number')
                                        .order('customers.name')

    customers_data = customers_with_unpaid_data.map do |customer|
      {
        id: customer.id,
        name: customer.name,
        phone_number: customer.phone_number,
        unpaid_amount: customer.total_unpaid_amount.to_f.round(2),
        invoice_count: customer.unpaid_invoice_count
      }
    end

    render json: {
      customers: customers_data,
      count: customers_data.length,
      month: Date::MONTHNAMES[month],
      year: year
    }
  end

  def send_unpaid_customers_message
    month = params[:month].to_i
    year = params[:year].to_i
    message = params[:message]

    if message.blank?
      render json: { success: false, error: 'Message cannot be empty' }
      return
    end

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    unpaid_customers = Customer.joins(:invoices)
                              .where(invoices: {
                                status: ['pending', 'overdue'],
                                invoice_date: start_date..end_date
                              })
                              .distinct

    twilio_service = TwilioWhatsappService.new
    success_count = 0
    failure_count = 0

    unpaid_customers.each do |customer|
      begin
        result = twilio_service.send_custom_message(customer.phone_number, message)
        if result
          success_count += 1
        else
          failure_count += 1
        end
      rescue => e
        Rails.logger.error "Failed to send WhatsApp message to #{customer.name}: #{e.message}"
        failure_count += 1
      end
    end

    render json: {
      success: true,
      message: "Messages sent: #{success_count} successful, #{failure_count} failed",
      success_count: success_count,
      failure_count: failure_count
    }
  end

  def total_customers_count
    total_customers = Customer.active.where.not(phone_number: [nil, '']).count

    render json: {
      success: true,
      total_customers: total_customers
    }
  end

  def total_customers_data
    customers = Customer.active
                      .where.not(phone_number: [nil, ''])
                      .select(:id, :name, :phone_number, :member_id)
                      .order(:name)

    customers_data = customers.map do |customer|
      {
        id: customer.id,
        name: customer.name,
        phone_number: customer.phone_number,
        member_id: customer.member_id
      }
    end

    render json: {
      success: true,
      customers: customers_data,
      count: customers_data.length
    }
  end

  def send_wishes_to_all
    message = params[:message]

    if message.blank?
      render json: { success: false, error: 'Message cannot be empty' }
      return
    end

    customers = Customer.active.where.not(phone_number: [nil, ''])
    twilio_service = TwilioWhatsappService.new
    success_count = 0
    failure_count = 0

    customers.find_each do |customer|
      begin
        result = twilio_service.send_custom_message(customer.phone_number, message)
        if result
          success_count += 1
        else
          failure_count += 1
        end
      rescue => e
        Rails.logger.error "Failed to send WhatsApp message to #{customer.name}: #{e.message}"
        failure_count += 1
      end
    end

    render json: {
      success: true,
      message: "Messages sent to all customers: #{success_count} successful, #{failure_count} failed",
      success_count: success_count,
      failure_count: failure_count,
      total_customers: customers.count
    }
  end
end