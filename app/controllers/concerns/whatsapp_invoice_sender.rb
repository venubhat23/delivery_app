# app/controllers/concerns/whatsapp_invoice_sender.rb
module WhatsappInvoiceSender
  extend ActiveSupport::Concern

  def send_invoice_via_whatsapp
    @invoice = Invoice.find(params[:id])

    # Use the enhanced WhatsApp service
    whatsapp_service = EnhancedTwilioWhatsappService.new
    result = whatsapp_service.send_invoice_notification(@invoice)

    respond_to do |format|
      if result
        format.html { redirect_to @invoice, notice: 'Invoice sent via WhatsApp successfully!' }
        format.json { render json: { success: true, message: 'Invoice sent successfully' } }
      else
        format.html { redirect_to @invoice, alert: 'Failed to send invoice via WhatsApp' }
        format.json { render json: { success: false, message: 'Failed to send invoice' } }
      end
    end
  end

  def send_invoice_to_custom_number
    @invoice = Invoice.find(params[:id])
    phone_number = params[:phone_number]

    if phone_number.blank?
      return redirect_to @invoice, alert: 'Phone number is required'
    end

    whatsapp_service = EnhancedTwilioWhatsappService.new
    result = whatsapp_service.send_invoice_notification(@invoice, phone_number: phone_number)

    respond_to do |format|
      if result
        format.html { redirect_to @invoice, notice: "Invoice sent to #{phone_number} via WhatsApp!" }
        format.json { render json: { success: true, message: 'Invoice sent successfully' } }
      else
        format.html { redirect_to @invoice, alert: 'Failed to send invoice via WhatsApp' }
        format.json { render json: { success: false, message: 'Failed to send invoice' } }
      end
    end
  end

  # Method to test PDF generation without sending WhatsApp
  def generate_pdf_url
    @invoice = Invoice.find(params[:id])

    whatsapp_service = EnhancedTwilioWhatsappService.new
    pdf_url = whatsapp_service.send(:generate_invoice_pdf_url, @invoice)

    respond_to do |format|
      if pdf_url.present?
        format.html { redirect_to pdf_url }
        format.json { render json: { success: true, pdf_url: pdf_url } }
      else
        format.html { redirect_to @invoice, alert: 'Failed to generate PDF URL' }
        format.json { render json: { success: false, message: 'Failed to generate PDF URL' } }
      end
    end
  end
end