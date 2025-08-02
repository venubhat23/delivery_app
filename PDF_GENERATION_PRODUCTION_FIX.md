# PDF Generation Production Fix

## Problem Description

The Rails application was failing to generate PDFs in production with the error:
```
PDF generation failed: Bad wkhtmltopdf's path: /usr/local/bin/wkhtmltopdf
RuntimeError: Bad wkhtmltopdf's path: /usr/local/bin/wkhtmltopdf
```

This error occurred because the application was configured to look for `wkhtmltopdf` at a hardcoded system path that didn't exist in the production Docker container.

## Root Cause Analysis

1. **Hardcoded Path**: The `config/initializers/wicked_pdf.rb` was configured with a hardcoded path `/usr/local/bin/wkhtmltopdf`
2. **Missing Binary**: The Docker container had wkhtmltopdf dependencies but not the binary itself
3. **Gem Not Used**: The `wkhtmltopdf-binary` gem was included in the Gemfile but not being used by the configuration

## Solution Implemented

### 1. Enhanced wkhtmltopdf Configuration (`config/initializers/wicked_pdf.rb`)

Created a robust configuration that can handle multiple scenarios:

```ruby
# Determine the best wkhtmltopdf executable path
def find_wkhtmltopdf_path
  # Try gem-provided binary first (more reliable in containerized environments)
  begin
    gem_path = Gem.bin_path('wkhtmltopdf-binary', 'wkhtmltopdf')
    return gem_path if File.executable?(gem_path)
  rescue Gem::GemNotFoundException
    Rails.logger.warn "wkhtmltopdf-binary gem not found, trying system installation"
  end
  
  # Try common system installation paths
  system_paths = [
    '/usr/local/bin/wkhtmltopdf',
    '/usr/bin/wkhtmltopdf',
    `which wkhtmltopdf`.strip
  ].compact.reject(&:empty?)
  
  system_paths.each do |path|
    return path if File.executable?(path)
  end
  
  # If nothing found, let wicked_pdf try to find it automatically
  Rails.logger.warn "No wkhtmltopdf executable found, letting wicked_pdf auto-detect"
  nil
end
```

**Benefits:**
- Tries gem-provided binary first (most reliable in Docker)
- Falls back to system installations
- Provides detailed logging for debugging
- Handles missing binaries gracefully

### 2. Updated Dockerfile

Enhanced the Dockerfile to install both the system wkhtmltopdf and additional fonts:

```dockerfile
# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client \
    # wkhtmltopdf and its dependencies
    wkhtmltopdf xvfb libfontconfig1 libxrender1 libxtst6 libxi6 libxrandr2 libasound2 libatk1.0-0 \
    libgtk-3-0 libdrm2 libxss1 libgconf-2-4 libxcomposite1 libxdamage1 libxcursor1 \
    libcairo-gobject2 libgtk2.0-0 libgdk-pixbuf2.0-0 libx11-6 \
    # Additional fonts for better PDF rendering
    fonts-liberation fonts-dejavu-core && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives
```

**Changes:**
- Added `wkhtmltopdf` package installation
- Added additional fonts (`fonts-liberation fonts-dejavu-core`)
- Kept all existing dependencies

### 3. Enhanced Error Handling (`app/controllers/invoices_controller.rb`)

Added comprehensive debugging information for PDF generation failures:

```ruby
# Log additional debugging information for wkhtmltopdf issues
if e.message.include?('wkhtmltopdf') || e.message.include?('Bad')
  Rails.logger.error "wkhtmltopdf configuration debug info:"
  Rails.logger.error "- exe_path configured: #{WickedPdf.config[:exe_path]}"
  Rails.logger.error "- File exists: #{WickedPdf.config[:exe_path] ? File.exist?(WickedPdf.config[:exe_path]) : 'N/A'}"
  Rails.logger.error "- File executable: #{WickedPdf.config[:exe_path] ? File.executable?(WickedPdf.config[:exe_path]) : 'N/A'}"
  
  # Additional system checks...
end
```

### 4. Testing Script (`bin/test-wkhtmltopdf`)

Created a comprehensive test script to verify wkhtmltopdf configuration:

```bash
./bin/test-wkhtmltopdf
```

This script checks:
- WickedPdf configuration
- Binary existence and executability
- System wkhtmltopdf availability
- Gem-provided binary
- Actual PDF generation test

## Deployment Steps

### For Docker/Container Deployment:

1. **Rebuild the Docker image** with the updated Dockerfile:
   ```bash
   docker build -t delivery_management .
   ```

2. **Deploy the new image** to your production environment

3. **Verify the fix** by running the test script in the container:
   ```bash
   docker exec -it <container_name> ./bin/test-wkhtmltopdf
   ```

### For Direct Server Deployment:

1. **Install wkhtmltopdf** on your production server:
   ```bash
   sudo apt-get update
   sudo apt-get install -y wkhtmltopdf fonts-liberation fonts-dejavu-core
   ```

2. **Deploy the updated code**

3. **Restart your Rails application**

4. **Run the test script**:
   ```bash
   RAILS_ENV=production ./bin/test-wkhtmltopdf
   ```

## Verification

After deployment, verify the fix by:

1. **Check the logs** for the initialization message:
   ```
   WickedPdf configured with exe_path: /path/to/wkhtmltopdf
   ```

2. **Test PDF generation** by accessing an invoice PDF URL

3. **Run the test script** to ensure all components are working

4. **Monitor application logs** for any remaining PDF generation errors

## Fallback Behavior

If PDF generation still fails, the application will:
1. Log detailed debugging information
2. Show a user-friendly error message: "PDF generation temporarily unavailable"
3. Render a print-friendly HTML version instead
4. Allow users to print the HTML version as a PDF using their browser

## Troubleshooting

### If PDFs still fail to generate:

1. **Check the logs** for the detailed debugging information
2. **Run the test script** to identify the specific issue
3. **Verify wkhtmltopdf installation**:
   ```bash
   which wkhtmltopdf
   wkhtmltopdf --version
   ```
4. **Check file permissions** if using a custom installation path

### Common Issues:

- **Permission denied**: Ensure the wkhtmltopdf binary is executable
- **Missing dependencies**: Install all required system libraries
- **Font issues**: Install additional font packages if PDFs have rendering problems
- **Xvfb not available**: Ensure xvfb is installed for headless operation

## Files Modified

- `config/initializers/wicked_pdf.rb` - Enhanced configuration with fallback logic
- `Dockerfile` - Added wkhtmltopdf installation and fonts
- `app/controllers/invoices_controller.rb` - Enhanced error handling and debugging
- `bin/test-wkhtmltopdf` - New testing script

## Dependencies

- `wicked_pdf` gem (already in Gemfile)
- `wkhtmltopdf-binary` gem (already in Gemfile)
- System `wkhtmltopdf` package
- Required system libraries (libfontconfig1, libxrender1, etc.)
- Additional fonts for better rendering

The solution provides multiple fallback mechanisms to ensure PDF generation works in various deployment scenarios while maintaining robust error handling and debugging capabilities.