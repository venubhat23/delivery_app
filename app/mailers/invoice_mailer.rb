# app/mailers/invoice_mailer.rb
class InvoiceMailer < ApplicationMailer
  default from: 'noreply@yourcompany.com'

  def payment_reminder(invoice)
    @invoice = invoice
    @customer = invoice.customer
    @days_until_due = (invoice.due_date - Date.current).to_i
    
    mail(
      to: @customer.email,
      subject: "Payment Reminder - Invoice #{@invoice.invoice_number}"
    )
  end

  def invoice_generated(invoice)
    @invoice = invoice
    @customer = invoice.customer
    
    mail(
      to: @customer.email,
      subject: "New Invoice #{@invoice.invoice_number} - Payment Due"
    )
  end

  def payment_confirmation(invoice)
    @invoice = invoice
    @customer = invoice.customer

    mail(
      to: @customer.email,
      subject: "Payment Received - Invoice #{@invoice.invoice_number}"
    )
  end

  def send_invoice_pdf(invoice, email)
    @invoice = invoice
    @customer = invoice.customer
    @invoice_items = invoice.invoice_items.includes(:product)
    @delivery_assignments = invoice.delivery_assignments.includes(:product, :user, :delivery_person).order(:completed_at, :scheduled_date)

    # For now, we'll send just the email without PDF attachment
    # PDF generation will be added later when wkhtmltopdf is properly configured
    mail(
      to: email,
      subject: "Invoice #{@invoice.formatted_number} - #{@customer.name}"
    )
  end
end