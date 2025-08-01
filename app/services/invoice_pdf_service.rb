require 'prawn'
require 'prawn/table'

class InvoicePdfService
  def initialize(customer, invoice_data = nil)
    @customer = customer
    @invoice_data = invoice_data || generate_sample_invoice_data
  end

  def generate_pdf
    Prawn::Document.new do |pdf|
      # Header
      pdf.text "INVOICE", size: 24, style: :bold, align: :center
      pdf.move_down 20
      
      # Company Info
      pdf.text "Your Company Name", size: 16, style: :bold
      pdf.text "Your Address Line 1"
      pdf.text "Your Address Line 2"
      pdf.text "Phone: +91-XXXXXXXXXX"
      pdf.text "Email: info@yourcompany.com"
      pdf.move_down 20
      
      # Customer Info
      pdf.text "Bill To:", style: :bold
      pdf.text "#{@customer.name}"
      pdf.text "Phone: #{@customer.phone_number}"
      pdf.move_down 20
      
      # Invoice Details
      pdf.text "Invoice #: #{@invoice_data[:invoice_number]}"
      pdf.text "Date: #{@invoice_data[:date]}"
      pdf.text "Due Date: #{@invoice_data[:due_date]}"
      pdf.move_down 20
      
      # Items Table
      table_data = [
        ['Item', 'Quantity', 'Rate', 'Amount']
      ]
      
      @invoice_data[:items].each do |item|
        table_data << [
          item[:description],
          item[:quantity].to_s,
          "₹#{item[:rate]}",
          "₹#{item[:amount]}"
        ]
      end
      
      table_data << ['', '', 'Total:', "₹#{@invoice_data[:total]}"]
      
      pdf.table(table_data, header: true, width: pdf.bounds.width) do
        row(0).font_style = :bold
        row(-1).font_style = :bold
        columns(1..3).align = :right
      end
      
      pdf.move_down 30
      pdf.text "Thank you for your business!", align: :center
    end
  end

  def save_to_file(filename = nil)
    filename ||= "invoice_#{@customer.id}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf"
    file_path = Rails.root.join('tmp', filename)
    
    # Ensure tmp directory exists
    FileUtils.mkdir_p(Rails.root.join('tmp'))
    
    pdf_content = generate_pdf
    File.open(file_path, 'wb') { |file| file.write(pdf_content.render) }
    
    file_path.to_s
  end

  def upload_to_storage
    pdf_content = generate_pdf.render
    filename = "invoice_#{@customer.id}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf"
    
    # Create a temporary file
    temp_file = Tempfile.new(['invoice', '.pdf'])
    temp_file.binmode
    temp_file.write(pdf_content)
    temp_file.rewind
    
    # Upload to Active Storage (assuming you have an Invoice model)
    invoice = create_invoice_record
    invoice.pdf.attach(
      io: temp_file,
      filename: filename,
      content_type: 'application/pdf'
    )
    
    temp_file.close
    temp_file.unlink
    
    invoice
  end

  private

  def generate_sample_invoice_data
    {
      invoice_number: "INV-#{rand(1000..9999)}",
      date: Date.current.strftime('%d/%m/%Y'),
      due_date: (Date.current + 30.days).strftime('%d/%m/%Y'),
      items: [
        {
          description: "Product/Service 1",
          quantity: 2,
          rate: 500,
          amount: 1000
        },
        {
          description: "Product/Service 2",
          quantity: 1,
          rate: 750,
          amount: 750
        }
      ],
      total: 1750
    }
  end

  def create_invoice_record
    # Assuming you have an Invoice model
    # If not, you can create it or modify this method
    if defined?(Invoice)
      Invoice.create!(
        customer: @customer,
        invoice_number: @invoice_data[:invoice_number],
        total_amount: @invoice_data[:total],
        invoice_date: Date.current
      )
    else
      # Create a simple OpenStruct if Invoice model doesn't exist
      invoice = OpenStruct.new(id: rand(1000..9999))
      def invoice.pdf
        @pdf ||= OpenStruct.new
      end
      def invoice.pdf.attach(options)
        # Mock attachment
        @attached_file = options
      end
      def invoice.pdf.attached?
        !@attached_file.nil?
      end
      invoice
    end
  end
end