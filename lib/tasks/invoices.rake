# lib/tasks/invoices.rake
namespace :invoices do
  desc "Generate monthly invoices for all customers"
  task :generate_monthly, [:month] => :environment do |t, args|
    month = args[:month] ? Date.parse("#{args[:month]}-01") : Date.current.beginning_of_month
    
    puts "Generating monthly invoices for #{month.strftime('%B %Y')}..."
    
    generated_invoices = Invoice.generate_monthly_invoices(month)
    
    if generated_invoices.any?
      puts "Successfully generated #{generated_invoices.count} invoices:"
      generated_invoices.each do |invoice|
        puts "  - #{invoice.invoice_number} for #{invoice.customer.name} ($#{invoice.total_amount})"
      end
    else
      puts "No invoices to generate for #{month.strftime('%B %Y')}"
    end
  end

  desc "Mark overdue invoices and send reminders"
  task check_overdue: :environment do
    puts "Checking for overdue invoices..."
    
    # Mark overdue invoices
    overdue_count = Invoice.where('due_date < ? AND status = ?', Date.current, 'pending')
                          .update_all(status: 'overdue')
    
    puts "Marked #{overdue_count} invoices as overdue"
    
    # Send reminders for invoices due in 3 days
    reminder_invoices = Invoice.where(
      due_date: Date.current + 3.days,
      status: 'pending'
    )
    
    reminder_count = 0
    reminder_invoices.each do |invoice|
      invoice.send_reminder!
      reminder_count += 1
    end
    
    puts "Sent #{reminder_count} payment reminders"
  end

  desc "Send overdue notifications to admin"
  task notify_overdue: :environment do
    overdue_invoices = Invoice.overdue.includes(:customer)
    
    if overdue_invoices.any?
      AdminMailer.overdue_invoices_alert(overdue_invoices).deliver_now
      puts "Sent overdue invoices alert for #{overdue_invoices.count} invoices"
    else
      puts "No overdue invoices found"
    end
  end

  desc "Generate invoice from delivery assignments"
  task :generate_from_deliveries, [:customer_id, :start_date, :end_date] => :environment do |t, args|
    customer = Customer.find(args[:customer_id])
    start_date = Date.parse(args[:start_date])
    end_date = Date.parse(args[:end_date])
    
    puts "Generating invoice for #{customer.name} from #{start_date} to #{end_date}..."
    
    assignments = DeliveryAssignment.where(
      customer: customer,
      status: 'completed',
      completed_at: start_date.beginning_of_day..end_date.end_of_day
    ).includes(:product)
    
    if assignments.empty?
      puts "No completed deliveries found for the specified period"
      exit
    end
    
    invoice = Invoice.create_invoice_from_assignments(customer, assignments, Date.current)
    
    if invoice
      puts "Successfully generated invoice #{invoice.invoice_number} for $#{invoice.total_amount}"
    else
      puts "Failed to generate invoice"
    end
  end

  desc "Clean up old invoices (older than 2 years)"
  task cleanup_old: :environment do
    cutoff_date = 2.years.ago
    old_invoices = Invoice.where('created_at < ?', cutoff_date)
    count = old_invoices.count
    
    if count > 0
      puts "Found #{count} invoices older than #{cutoff_date.strftime('%Y-%m-%d')}"
      print "Are you sure you want to delete them? (y/N): "
      response = STDIN.gets.chomp
      
      if response.downcase == 'y'
        old_invoices.destroy_all
        puts "Deleted #{count} old invoices"
      else
        puts "Cleanup cancelled"
      end
    else
      puts "No old invoices found"
    end
  end

  desc "Generate monthly invoices automatically (for cron job)"
  task auto_generate_monthly: :environment do
    MonthlyInvoiceGenerationJob.perform_later
  end

  desc "Check overdue invoices automatically (for cron job)"
  task auto_check_overdue: :environment do
    OverdueInvoiceCheckerJob.perform_later
  end
end