# app/controllers/reports_controller.rb
class ReportsController < ApplicationController
  before_action :require_login
  
  def index
    @reports = Report.where(user: current_user).order(created_at: :desc) if defined?(Report)
    @reports ||= []
  end
  
  def generate_gst_report
    from_date = params[:from_date]
    to_date = params[:to_date]
    
    if from_date.blank? || to_date.blank?
      render json: { 
        success: false, 
        message: "Please select both from and to dates" 
      }
      return
    end
    
    begin
      # Create a new report record
      report = create_report_record(from_date, to_date)
      
      render json: { 
        success: true, 
        message: "GST Report generated successfully",
        report: {
          id: report.id,
          name: report.name,
          generated_at: report.created_at.strftime("%B %d, %Y at %I:%M %p"),
          from_date: from_date,
          to_date: to_date
        }
      }
    rescue => e
      render json: { 
        success: false, 
        message: "Failed to generate report: #{e.message}" 
      }
    end
  end
  
  def show
    @report = find_report
    
    if @report.nil?
      redirect_to reports_path, alert: "Report not found"
      return
    end
    
    # Generate GST report data
    from_date = @report.respond_to?(:from_date) ? @report.from_date : Date.parse(params[:from_date] || 1.month.ago.to_s)
    to_date = @report.respond_to?(:to_date) ? @report.to_date : Date.parse(params[:to_date] || Date.current.to_s)
    
    @gst_data = get_gst_report_data(from_date, to_date)
    @from_date = from_date
    @to_date = to_date
    
    respond_to do |format|
      format.html
      format.json { render json: @gst_data }
    end
  end

  def download_pdf
    report = find_report
    
    if report.nil?
      redirect_to reports_path, alert: "Report not found"
      return
    end
    
    # Generate PDF content
    html_content = generate_gst_pdf_content(report)
    
    respond_to do |format|
      format.pdf do
        render html: html_content.html_safe, layout: false
      end
      format.html do
        render html: html_content.html_safe, layout: false
      end
    end
  end
  
  private
  
  def number_with_delimiter(number)
    # Simple number formatting helper
    return "0.0" if number.nil? || number == 0
    sprintf("%.2f", number).gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
  end
  
  def find_report
    if defined?(Report)
      Report.find_by(id: params[:id], user: current_user)
    else
      # Fallback for demo purposes
      OpenStruct.new(
        id: params[:id],
        name: "GST Report #{params[:id]}",
        from_date: 1.month.ago.to_date,
        to_date: Date.current,
        created_at: Time.current
      )
    end
  end
  
  def create_report_record(from_date, to_date)
    if defined?(Report)
      Report.create!(
        name: "GST Report - #{Date.parse(from_date).strftime('%b %d')} to #{Date.parse(to_date).strftime('%b %d, %Y')}",
        report_type: 'gst',
        from_date: Date.parse(from_date),
        to_date: Date.parse(to_date),
        user: current_user
      )
    else
      # Fallback for demo purposes
      OpenStruct.new(
        id: rand(1000..9999),
        name: "GST Report - #{Date.parse(from_date).strftime('%b %d')} to #{Date.parse(to_date).strftime('%b %d, %Y')}",
        report_type: 'gst',
        from_date: Date.parse(from_date),
        to_date: Date.parse(to_date),
        created_at: Time.current,
        user: current_user
      )
    end
  end
  
  def generate_gst_pdf_content(report)
    # Generate GST report data
    from_date = report.respond_to?(:from_date) ? report.from_date : Date.parse(params[:from_date] || 1.month.ago.to_s)
    to_date = report.respond_to?(:to_date) ? report.to_date : Date.parse(params[:to_date] || Date.current.to_s)
    gst_data = get_gst_report_data(from_date, to_date)
    
    # Generate HTML content for PDF with proper table formatting
    html_content = generate_pdf_html_table(report, gst_data, from_date, to_date)
    
    # Return HTML content that can be converted to PDF by the browser
    html_content
  end
  
  def generate_pdf_html_table(report, gst_data, from_date, to_date)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>GST Report - #{report.respond_to?(:name) ? report.name : "GST Report"}</title>
        <style>
          body { font-family: Arial, sans-serif; font-size: 12px; margin: 20px; }
          .header { text-align: center; margin-bottom: 30px; }
          .company-info { margin-bottom: 20px; }
          .report-title { font-size: 18px; font-weight: bold; margin-bottom: 10px; }
          .date-range { font-size: 14px; color: #666; margin-bottom: 20px; }
          table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
          th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
          th { background-color: #f2f2f2; font-weight: bold; text-align: center; }
          .text-right { text-align: right; }
          .text-center { text-align: center; }
          .total-row { background-color: #f9f9f9; font-weight: bold; }
          .summary { margin-top: 30px; }
          .summary-table { width: 50%; }
          .page-break { page-break-after: always; }
        </style>
      </head>
      <body>
        <div class="header">
          <div class="report-title">GSTR-1 - Atma Nirbhar Farm</div>
          <div class="company-info">
            Mobile: 9972808044<br>
            GST No: 29AOIPT8113K1ZC
          </div>
          <div class="date-range">
            Date Range: #{from_date.strftime('%d/%m/%Y')} to #{to_date.strftime('%d/%m/%Y')}<br>
            Generated On: #{Time.current.strftime('%d/%m/%Y at %I:%M %p')}
          </div>
        </div>

        <h3>Sales Transactions</h3>
        <table>
          <thead>
            <tr>
              <th rowspan="2">GSTIN</th>
              <th rowspan="2">Customer Name</th>
              <th colspan="2">Place of Supply</th>
              <th colspan="3">Invoice Details</th>
              <th colspan="6">Amount of Tax</th>
              <th rowspan="2">Total Tax</th>
            </tr>
            <tr>
              <th>State Code</th>
              <th>State Name</th>
              <th>Invoice No.</th>
              <th>Invoice Date</th>
              <th>Invoice Value</th>
              <th>Tax %</th>
              <th>Taxable Value</th>
              <th>Central Tax</th>
              <th>State/UT Tax</th>
              <th>Integrated Tax</th>
              <th>CESS</th>
            </tr>
          </thead>
          <tbody>
            #{gst_data[:sales_transactions].map { |transaction|
              <<~ROW
                <tr>
                  <td class="text-center">-</td>
                  <td>#{transaction[:customer_name]}</td>
                  <td class="text-center">#{transaction[:state_code]}</td>
                  <td>#{transaction[:state_name]}</td>
                  <td>#{transaction[:invoice_no]}</td>
                  <td class="text-center">#{transaction[:invoice_date]}</td>
                  <td class="text-right">₹#{number_with_delimiter(transaction[:invoice_value])}</td>
                  <td class="text-right">#{transaction[:tax_rate]}%</td>
                  <td class="text-right">₹#{number_with_delimiter(transaction[:taxable_value])}</td>
                  <td class="text-right">₹#{number_with_delimiter(transaction[:central_tax])}</td>
                  <td class="text-right">₹#{number_with_delimiter(transaction[:state_tax])}</td>
                  <td class="text-right">₹#{number_with_delimiter(transaction[:integrated_tax])}</td>
                  <td class="text-right">₹#{number_with_delimiter(transaction[:cess])}</td>
                  <td class="text-right">₹#{number_with_delimiter(transaction[:total_tax])}</td>
                </tr>
              ROW
            }.join}
            <tr class="total-row">
              <td colspan="6"><strong>Total</strong></td>
              <td class="text-right"><strong>₹#{number_with_delimiter(gst_data[:summary][:total_sales])}</strong></td>
              <td></td>
              <td class="text-right"><strong>₹#{number_with_delimiter(gst_data[:summary][:total_sales] - gst_data[:summary][:total_tax])}</strong></td>
              <td class="text-right"><strong>₹#{number_with_delimiter(gst_data[:summary][:cgst])}</strong></td>
              <td class="text-right"><strong>₹#{number_with_delimiter(gst_data[:summary][:sgst])}</strong></td>
              <td class="text-right"><strong>₹#{number_with_delimiter(gst_data[:summary][:igst])}</strong></td>
              <td class="text-right"><strong>₹0.0</strong></td>
              <td class="text-right"><strong>₹#{number_with_delimiter(gst_data[:summary][:total_tax])}</strong></td>
            </tr>
          </tbody>
        </table>

        <div class="summary">
          <h3>Tax Summary</h3>
          <table class="summary-table">
            <tr>
              <td><strong>Total Sales:</strong></td>
              <td class="text-right"><strong>₹#{number_with_delimiter(gst_data[:summary][:total_sales])}</strong></td>
            </tr>
            <tr>
              <td><strong>Total Tax Collected:</strong></td>
              <td class="text-right"><strong>₹#{number_with_delimiter(gst_data[:summary][:total_tax])}</strong></td>
            </tr>
            <tr>
              <td>CGST:</td>
              <td class="text-right">₹#{number_with_delimiter(gst_data[:summary][:cgst])}</td>
            </tr>
            <tr>
              <td>SGST:</td>
              <td class="text-right">₹#{number_with_delimiter(gst_data[:summary][:sgst])}</td>
            </tr>
            <tr>
              <td>IGST:</td>
              <td class="text-right">₹#{number_with_delimiter(gst_data[:summary][:igst])}</td>
            </tr>
          </table>
        </div>

        <div style="margin-top: 50px; text-align: center; font-size: 10px; color: #666;">
          Report generated by Atmanirbhar Farm Bangalore<br>
          #{Time.current.strftime('%B %d, %Y at %I:%M %p')}
        </div>
      </body>
      </html>
    HTML
  end
  
  def generate_gst_report_html(report)
    # Generate GST report content based on the date range
    from_date = report.respond_to?(:from_date) ? report.from_date : Date.parse(params[:from_date] || 1.month.ago.to_s)
    to_date = report.respond_to?(:to_date) ? report.to_date : Date.parse(params[:to_date] || Date.current.to_s)
    
    # Get actual GST data from sales invoices
    gst_data = get_gst_report_data(from_date, to_date)
    
    <<~HTML
      GST REPORT
      ==========
      
      Report Name: #{report.respond_to?(:name) ? report.name : "GST Report"}
      Date Range: #{from_date.strftime('%B %d, %Y')} to #{to_date.strftime('%B %d, %Y')}
      Generated On: #{Time.current.strftime('%B %d, %Y at %I:%M %p')}
      Generated By: #{current_user.name}
      
      SUMMARY
      -------
      Total Sales: ₹#{gst_data[:summary][:total_sales]}
      Total Tax Collected: ₹#{gst_data[:summary][:total_tax]}
      CGST: ₹#{gst_data[:summary][:cgst]}
      SGST: ₹#{gst_data[:summary][:sgst]}
      IGST: ₹#{gst_data[:summary][:igst]}
      
      SALES TRANSACTIONS
      ------------------
      #{gst_data[:sales_transactions].map { |t| 
        "#{t[:customer_name]} | #{t[:invoice_no]} | #{t[:invoice_date]} | ₹#{t[:invoice_value]} | #{t[:tax_rate]}% | ₹#{t[:tax_amount]}"
      }.join("\n")}
      
      ---
      Report generated by Atmanirbhar Farm Bangalore
      #{Time.current.strftime('%B %d, %Y at %I:%M %p')}
    HTML
  end

  def get_gst_report_data(from_date, to_date)
    # Get sales invoices for the date range
    sales_invoices = SalesInvoice.includes(:sales_invoice_items, :customer, :sales_customer)
                                 .where(invoice_date: from_date..to_date)
                                 .where.not(status: 'cancelled')

    # Get delivery assignments for the date range (if they have invoice data)
    delivery_assignments = DeliveryAssignment.includes(:customer, :product, :invoice)
                                           .where(scheduled_date: from_date..to_date, status: 'completed')

    sales_transactions = []
    total_sales = 0
    total_tax = 0
    cgst_total = 0
    sgst_total = 0
    igst_total = 0

    # Process sales invoices
    sales_invoices.each do |invoice|
      customer_name = invoice.customer_name || invoice.get_customer&.name || "Unknown"
      customer_state = get_customer_state(invoice)
      
      invoice.sales_invoice_items.each do |item|
        tax_amount = item.tax_amount || 0
        invoice_value = item.total_with_tax || 0
        
        # Calculate GST breakdown based on state
        if customer_state == "Karnataka" # Same state as business
          cgst_amount = tax_amount / 2
          sgst_amount = tax_amount / 2
          igst_amount = 0
        else # Different state
          cgst_amount = 0
          sgst_amount = 0
          igst_amount = tax_amount
        end

        sales_transactions << {
          customer_name: customer_name,
          state_code: get_state_code(customer_state),
          state_name: customer_state,
          invoice_no: invoice.invoice_number,
          invoice_date: invoice.invoice_date.strftime('%d/%m/%Y'),
          invoice_value: invoice_value.round(2),
          tax_rate: item.tax_rate || 0,
          taxable_value: (invoice_value - tax_amount).round(2),
          central_tax: cgst_amount.round(2),
          state_tax: sgst_amount.round(2),
          integrated_tax: igst_amount.round(2),
          cess: 0.0,
          total_tax: tax_amount.round(2)
        }

        total_sales += invoice_value
        total_tax += tax_amount
        cgst_total += cgst_amount
        sgst_total += sgst_amount
        igst_total += igst_amount
      end
    end

    # Process delivery assignments that don't have invoices yet
    delivery_assignments.where(invoice_generated: false).each do |assignment|
      customer_name = assignment.customer_name
      customer_state = assignment.customer&.state || "Karnataka"
      
      # Calculate tax based on product price and standard tax rate (assuming 5% for milk products)
      tax_rate = 5.0
      invoice_value = assignment.total_amount || 0
      tax_amount = (invoice_value * tax_rate / (100 + tax_rate)).round(2)
      taxable_value = invoice_value - tax_amount

      # Calculate GST breakdown based on state
      if customer_state == "Karnataka"
        cgst_amount = tax_amount / 2
        sgst_amount = tax_amount / 2
        igst_amount = 0
      else
        cgst_amount = 0
        sgst_amount = 0
        igst_amount = tax_amount
      end

      sales_transactions << {
        customer_name: customer_name,
        state_code: get_state_code(customer_state),
        state_name: customer_state,
        invoice_no: "DA-#{assignment.id}",
        invoice_date: assignment.scheduled_date.strftime('%d/%m/%Y'),
        invoice_value: invoice_value.round(2),
        tax_rate: tax_rate,
        taxable_value: taxable_value.round(2),
        central_tax: cgst_amount.round(2),
        state_tax: sgst_amount.round(2),
        integrated_tax: igst_amount.round(2),
        cess: 0.0,
        total_tax: tax_amount.round(2)
      }

      total_sales += invoice_value
      total_tax += tax_amount
      cgst_total += cgst_amount
      sgst_total += sgst_amount
      igst_total += igst_amount
    end

    {
      sales_transactions: sales_transactions,
      summary: {
        total_sales: total_sales.round(2),
        total_tax: total_tax.round(2),
        cgst: cgst_total.round(2),
        sgst: sgst_total.round(2),
        igst: igst_total.round(2)
      }
    }
  end

  def get_customer_state(invoice)
    customer = invoice.get_customer
    return customer.state if customer&.state.present?
    
    # Default to Karnataka if no state is specified
    "Karnataka"
  end

  def get_state_code(state_name)
    state_codes = {
      "Karnataka" => "29",
      "Tamil Nadu" => "33",
      "Kerala" => "32",
      "Andhra Pradesh" => "37",
      "Telangana" => "36",
      "Maharashtra" => "27",
      "Gujarat" => "24",
      "Rajasthan" => "08",
      "Uttar Pradesh" => "09",
      "West Bengal" => "19",
      "Bihar" => "10",
      "Madhya Pradesh" => "23",
      "Odisha" => "21",
      "Punjab" => "03",
      "Haryana" => "06",
      "Himachal Pradesh" => "02",
      "Uttarakhand" => "05",
      "Jharkhand" => "20",
      "Chhattisgarh" => "22",
      "Assam" => "18",
      "Tripura" => "16",
      "Meghalaya" => "17",
      "Manipur" => "14",
      "Nagaland" => "13",
      "Mizoram" => "15",
      "Arunachal Pradesh" => "12",
      "Sikkim" => "11",
      "Goa" => "30",
      "Delhi" => "07",
      "Puducherry" => "34",
      "Chandigarh" => "04",
      "Andaman and Nicobar Islands" => "35",
      "Dadra and Nagar Haveli and Daman and Diu" => "26",
      "Lakshadweep" => "31",
      "Ladakh" => "38",
      "Jammu and Kashmir" => "01"
    }
    
    state_codes[state_name] || "29" # Default to Karnataka
  end
end