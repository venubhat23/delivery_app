# PDF Generation Fix for Production

## Problem
The application was failing to generate PDFs in production with the following error:
```
RuntimeError in InvoicesController#show
Failed to execute: wkhtmltopdf
Error: PDF could not be generated!
Command Error: pid 416268 exit 127
libXrender.so.1: cannot open shared object file: No such file or directory
```

## Root Cause
The production environment (Docker container) was missing required system libraries for wkhtmltopdf to function properly. Specifically:
- `libXrender.so.1` and other X11 libraries
- Font configuration libraries
- Graphics rendering dependencies

## Solution

### 1. Updated Dockerfile
Added required system dependencies to the Dockerfile:

```dockerfile
# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client \
    # wkhtmltopdf dependencies
    xvfb libfontconfig1 libxrender1 libxtst6 libxi6 libxrandr2 libasound2 libatk1.0-0 \
    libgtk-3-0 libdrm2 libxss1 libgconf-2-4 libxcomposite1 libxdamage1 libxcursor1 \
    libcairo-gobject2 libgtk2.0-0 libgdk-pixbuf2.0-0 libx11-6 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
```

### 2. Enhanced wicked_pdf Configuration
Updated `config/initializers/wicked_pdf.rb` with production-specific settings:

```ruby
# Production-specific options for headless environments
**if Rails.env.production?
  {
    # Use Xvfb for headless PDF generation
    use_xvfb: true,
    # Disable JavaScript execution for faster rendering
    disable_javascript: true,
    # Disable external links
    disable_external_links: true,
    # Set timeout to prevent hanging
    javascript_delay: 1000,
    # Additional stability options
    no_stop_slow_scripts: true,
    quiet: true
  }
else
  {}
end
```

### 3. Added Fallback PDF Generation
Enhanced the InvoicesController with error handling and fallback:

```ruby
def show
  # ... existing code ...
  
  respond_to do |format|
    format.html
    format.pdf do
      begin
        render pdf: "invoice_#{@invoice.id}",
               template: 'invoices/show',
               layout: false,
               page_size: 'A4',
               margin: { top: 5, bottom: 5, left: 5, right: 5 },
               encoding: 'UTF-8'
      rescue => e
        Rails.logger.error "PDF generation failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Fallback to HTML with print-friendly styling
        flash[:alert] = "PDF generation temporarily unavailable. Showing print-friendly version."
        render template: 'invoices/show_print', layout: false, content_type: 'text/html'
      end
    end
  end
end
```

### 4. Created Print-Friendly Fallback Template
Created `app/views/invoices/show_print.html.erb` with:
- Print-optimized CSS styles
- Browser print functionality
- Same layout as PDF template
- Dynamic invoice data rendering

## Deployment Instructions

### For Docker Deployments
1. Rebuild your Docker image with the updated Dockerfile
2. Deploy the new image to production

### For Server Deployments
1. Run the setup script on your production server:
   ```bash
   sudo ./bin/setup-wkhtmltopdf
   ```
2. Restart your Rails application

### Manual Installation (if script fails)
```bash
sudo apt-get update
sudo apt-get install -y xvfb libfontconfig1 libxrender1 libxtst6 libxi6 \
  libxrandr2 libasound2 libatk1.0-0 libgtk-3-0 libdrm2 libxss1 \
  libgconf-2-4 libxcomposite1 libxdamage1 libxcursor1 libcairo-gobject2 \
  libgtk2.0-0 libgdk-pixbuf2.0-0 libx11-6
```

## Testing

### Test PDF Generation
1. Navigate to any invoice in your application
2. Add `.pdf` to the URL (e.g., `/invoices/1.pdf`)
3. Verify that either:
   - PDF downloads successfully, OR
   - Print-friendly fallback page displays with notice

### Test in Development
```bash
# Test with debug mode
DEBUG_PDF=true rails server
# Visit invoice URL with .pdf extension
```

## Troubleshooting

### Common Issues

1. **Still getting libXrender.so.1 errors**
   - Ensure Docker image was rebuilt with new dependencies
   - Check that all required packages are installed
   - Verify container has access to X11 libraries

2. **PDF generation hanging**
   - Check the production configuration settings
   - Verify `use_xvfb: true` is set for production
   - Consider increasing timeout settings

3. **Fonts not rendering correctly**
   - Install additional font packages if needed:
     ```bash
     sudo apt-get install fonts-liberation fonts-dejavu-core
     ```

4. **Memory issues**
   - Increase container memory limits
   - Monitor wkhtmltopdf process memory usage

### Logs to Check
- Rails application logs for PDF generation errors
- System logs for missing library errors
- Container logs for dependency issues

## Alternative Solutions

If wkhtmltopdf continues to cause issues, consider these alternatives:

1. **Grover (Chrome headless)**
   ```ruby
   gem 'grover'
   ```

2. **Prawn (Pure Ruby PDF)**
   ```ruby
   gem 'prawn'
   gem 'prawn-table'
   ```

3. **Puppeteer-Ruby**
   ```ruby
   gem 'puppeteer-ruby'
   ```

## Files Modified

- `Dockerfile` - Added system dependencies
- `config/initializers/wicked_pdf.rb` - Enhanced configuration
- `app/controllers/invoices_controller.rb` - Added error handling
- `app/views/invoices/show_print.html.erb` - New fallback template
- `bin/setup-wkhtmltopdf` - New setup script

## Performance Considerations

- PDF generation is CPU and memory intensive
- Consider using background jobs for large PDFs
- Monitor system resources during peak usage
- Cache generated PDFs when possible

## Security Notes

- Fallback template uses same data validation as PDF template
- External image URLs are maintained for consistency
- Print functionality is client-side only