# PDF Generation Issue Resolution

## Problem Summary
The application was showing "PDF generation temporarily unavailable. Showing print-friendly version." when users tried to access invoice PDFs. This was due to missing system dependencies for wkhtmltopdf.

## Root Cause
1. **Missing wkhtmltopdf**: The system didn't have wkhtmltopdf installed
2. **Missing system libraries**: Required X11 and graphics libraries were not installed
3. **Incompatible gem binary**: The wkhtmltopdf-binary gem doesn't support Ubuntu 25.04

## Solution Implemented

### 1. Installed System Dependencies
```bash
sudo apt-get update
sudo apt-get install -y xvfb libfontconfig1 libxrender1 libxtst6 libxi6 \
  libxrandr2 libasound2t64 libatk1.0-0t64 libgtk-3-0t64 libdrm2 libxss1 \
  libxcomposite1 libxdamage1 libxcursor1 libcairo-gobject2 libgtk2.0-0t64 \
  libgdk-pixbuf2.0-0 libx11-6
```

### 2. Installed wkhtmltopdf
```bash
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
sudo apt-get install -y xfonts-75dpi
sudo dpkg -i wkhtmltox_0.12.6.1-3.jammy_amd64.deb
```

### 3. Updated wicked_pdf Configuration
Updated `config/initializers/wicked_pdf.rb` to use system-installed wkhtmltopdf instead of the gem binary:

```ruby
# Before
exe_path: Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf'),

# After  
exe_path: '/usr/local/bin/wkhtmltopdf',
```

### 4. Created HTML Fallback Template
Created `app/views/invoices/show_print.html.erb` with:
- Print-friendly CSS styling
- Browser print functionality via JavaScript
- Warning message about PDF unavailability
- Same invoice layout as PDF template
- Print-specific media queries to hide UI elements when printing

## Fallback Mechanism
The application now has a robust fallback system:

1. **Primary**: Attempts PDF generation using wkhtmltopdf
2. **Fallback**: If PDF generation fails, displays HTML template with:
   - Warning message: "PDF generation temporarily unavailable"
   - Print button for browser-based printing
   - Same styling and data as PDF version
   - Print-optimized CSS

## Files Modified
- `config/initializers/wicked_pdf.rb` - Updated exe_path configuration
- `app/views/invoices/show_print.html.erb` - New HTML fallback template

## Testing Results
✅ wkhtmltopdf installed and working (version 0.12.6.1)  
✅ System dependencies installed  
✅ PDF generation test successful  
✅ HTML fallback template created  
✅ Print functionality working  

## Current Status
- **PDF Generation**: ✅ WORKING - Should now generate PDFs successfully
- **Fallback System**: ✅ ACTIVE - HTML template available if PDF fails
- **User Experience**: ✅ IMPROVED - Users can still print invoices even if PDF fails

## Next Steps
1. **Test in Production**: Verify PDF generation works with actual invoice data
2. **Monitor Logs**: Check for any remaining PDF generation errors
3. **Performance**: Monitor PDF generation performance under load
4. **Alternative Solutions**: Consider Grover (Chrome headless) or Prawn if issues persist

## Troubleshooting
If PDF generation still fails:
1. Check Rails logs for specific error messages
2. Verify wkhtmltopdf is accessible: `which wkhtmltopdf`
3. Test wkhtmltopdf directly: `wkhtmltopdf --version`
4. Check system memory and disk space
5. Consider using background jobs for large invoices

The application now has both working PDF generation AND a reliable fallback mechanism, ensuring users can always access their invoices in some form.