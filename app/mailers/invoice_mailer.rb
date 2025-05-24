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
end