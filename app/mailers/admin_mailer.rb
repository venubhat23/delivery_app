

# app/mailers/admin_mailer.rb
class AdminMailer < ApplicationMailer
  default from: 'noreply@yourcompany.com'

  def monthly_invoices_generated(invoices, month)
    @invoices = invoices
    @month = month
    @total_amount = invoices.sum(&:total_amount)
    
    mail(
      to: 'admin@yourcompany.com',
      subject: "Monthly Invoices Generated - #{month.strftime('%B %Y')}"
    )
  end

  def overdue_invoices_alert(overdue_invoices)
    @overdue_invoices = overdue_invoices
    @total_overdue_amount = overdue_invoices.sum(&:total_amount)
    
    mail(
      to: 'admin@yourcompany.com',
      subject: "Overdue Invoices Alert - #{@overdue_invoices.count} invoices"
    )
  end
end