require 'twilio-ruby'
require 'json'

class TwilioTemplateService
  def initialize
    @account_sid = ENV['TWILIO_ACCOUNT_SID']
    @auth_token = ENV['TWILIO_AUTH_TOKEN']
    @content_sid = 'HX9e05da399e269e1982f8b5bcf4bee0a2' # atmanirbhar_farm_invoice_6 template
    @from_number = 'whatsapp:+917619444966'
    @client = Twilio::REST::Client.new(@account_sid, @auth_token)
  end

  def send_individual_message(customer_id, message)
    customer = Customer.find_by(id: customer_id)

    if customer.blank?
      return { success: false, error: 'Customer not found' }
    end

    if message.blank?
      return { success: false, error: 'Message cannot be empty' }
    end

    result = send_template_message(customer.phone_number)

    if result
      {
        success: true,
        message: "Message sent successfully to #{customer.name}"
      }
    else
      {
        success: false,
        error: "Failed to send message to #{customer.name}"
      }
    end
  end

  def unpaid_customers_data(month = nil, year = nil)
    month = month&.to_i || Date.current.month
    year = year&.to_i || Date.current.year

    month = Date.current.month if month == 0
    year = Date.current.year if year == 0

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

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

    {
      customers: customers_data,
      count: customers_data.length,
      month: Date::MONTHNAMES[month],
      year: year
    }
  end

  def send_unpaid_customers_message(month, year, message)
    if message.blank?
      return { success: false, error: 'Message cannot be empty' }
    end

    start_date = Date.new(year, month, 1).beginning_of_month
    end_date = start_date.end_of_month

    unpaid_customers = Customer.joins(:invoices)
                              .where(invoices: {
                                status: ['pending', 'overdue'],
                                invoice_date: start_date..end_date
                              })
                              .distinct

    success_count = 0
    failure_count = 0

    unpaid_customers.each do |customer|
      begin
        result = send_template_message(customer.phone_number)
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

    {
      success: true,
      message: "Messages sent: #{success_count} successful, #{failure_count} failed",
      success_count: success_count,
      failure_count: failure_count
    }
  end

  private

  def send_template_message(phone_number)
    phone_number = format_phone_number(phone_number)

    message = @client.messages.create(
      content_sid: @content_sid,
      to: "whatsapp:#{phone_number}",
      from: @from_number
    )

    Rails.logger.info "WhatsApp template message sent successfully. SID: #{message.sid}"
    true
  rescue => e
    Rails.logger.error "Twilio WhatsApp template error: #{e.message}"
    false
  end

  def format_phone_number(phone)
    cleaned = phone.gsub(/\D/, '')

    if cleaned.length == 10
      "+91#{cleaned}"
    elsif cleaned.length == 12 && cleaned.start_with?('91')
      "+#{cleaned}"
    elsif cleaned.length == 13 && cleaned.start_with?('+91')
      cleaned
    else
      "+91#{cleaned}"
    end
  end
end