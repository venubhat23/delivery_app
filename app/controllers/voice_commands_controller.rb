class VoiceCommandsController < ApplicationController
  before_action :authenticate_user!
  
  def process_command
    command = params[:command]&.downcase&.strip
    
    Rails.logger.info "Processing voice command: #{command}"
    
    case command
    when /generate monthly for all/i, /generate monthly invoices/i, /monthly invoices for all/i
      handle_monthly_invoice_generation
    when /generate invoice/i
      handle_single_invoice_generation
    when /send whatsapp/i, /send notifications/i
      handle_whatsapp_notifications
    else
      render json: { 
        success: false, 
        message: "Command not recognized. Try saying 'Generate Monthly for All'",
        recognized_command: command
      }
    end
  end
  
  private
  
  def handle_monthly_invoice_generation
    begin
      month = Date.current.month
      year = Date.current.year
      
      # Call the existing monthly invoice generation method
      results = Invoice.generate_monthly_invoices_for_all_customers(month, year)
      success_count = 0
      failure_count = 0
      
      results.each do |result|
        if result[:result][:success]
          success_count += 1
          # Send WhatsApp message for successful invoice
          begin
            send_whatsapp_invoice(result[:result][:invoice])
          rescue => e
            Rails.logger.error "WhatsApp sending failed for invoice #{result[:result][:invoice].id}: #{e.message}"
          end
        else
          failure_count += 1
        end
      end
      
      message = if success_count > 0
        "✅ Successfully generated #{success_count} monthly invoices and sent WhatsApp notifications!"
      elsif failure_count > 0
        "⚠️ #{failure_count} invoices could not be generated. Please check the logs."
      else
        "ℹ️ No customers with completed deliveries found for this month."
      end
      
      render json: { 
        success: true, 
        message: message,
        details: {
          success_count: success_count,
          failure_count: failure_count,
          month: Date::MONTHNAMES[month],
          year: year
        }
      }
      
    rescue => e
      Rails.logger.error "Voice command error: #{e.message}"
      render json: { 
        success: false, 
        message: "❌ Error occurred while generating invoices: #{e.message}" 
      }
    end
  end
  
  def handle_single_invoice_generation
    render json: { 
      success: true, 
      message: "🔄 Redirecting to invoice generation page...",
      redirect_url: generate_invoices_path
    }
  end
  
  def handle_whatsapp_notifications
    render json: { 
      success: true, 
      message: "📱 WhatsApp notification feature is ready. Use 'Generate Monthly for All' to send invoices automatically."
    }
  end
  
  # Reuse the existing WhatsApp sending method from InvoicesController
  def send_whatsapp_invoice(invoice)
    return unless invoice&.customer&.phone_number.present?
    
    whatsapp_service = WhatsappService.new
    
    # Generate PDF URL (you might need to adjust this based on your setup)
    pdf_url = url_for(controller: 'invoices', action: 'show', id: invoice.id, format: 'pdf')
    message = "📄 Your monthly invoice ##{invoice.formatted_number} for ₹#{invoice.total_amount} is ready! Due date: #{invoice.due_date.strftime('%d %B %Y')}"
    
    # Send WhatsApp message with PDF
    whatsapp_service.send_pdf(invoice.customer.phone_number, pdf_url, message)
    
    Rails.logger.info "WhatsApp invoice sent to #{invoice.customer.name} (#{invoice.customer.phone_number})"
  end
end