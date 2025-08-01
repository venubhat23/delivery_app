# EC2 Deployment Configuration for WhatsApp Sharing Fix

## Issue Fixed
The WhatsApp sharing feature was failing with the error:
```
WhatsApp sharing error: Missing host to link to! Please provide the :host parameter, set default_url_options[:host], or set :only_path to true
```

## Changes Made

### 1. Updated InvoicesController#share_whatsapp method
- Added explicit host parameter when generating public URLs
- Added fallback host resolution logic

### 2. Updated Production Environment Configuration
- Made host configuration dynamic using `APP_HOST` environment variable
- Added proper host authorization for security

### 3. Enhanced Invoice Model
- Added robust host resolution in `public_url` method
- Multiple fallback options for host determination

## EC2 Deployment Setup

### Set Environment Variable
On your EC2 instance, set the `APP_HOST` environment variable to your actual domain:

```bash
# For development.eb environment on EC2
export APP_HOST="your-actual-ec2-domain.com"

# Or if using a specific subdomain for development.eb
export APP_HOST="development.atmanirbharfarm.work.gd"

# Make it persistent by adding to your shell profile
echo 'export APP_HOST="your-actual-ec2-domain.com"' >> ~/.bashrc
source ~/.bashrc
```

### Docker/Container Deployment
If using Docker or containers, set the environment variable in your deployment:

```bash
# Docker run
docker run -e APP_HOST="your-actual-ec2-domain.com" your-app

# Docker Compose
environment:
  - APP_HOST=your-actual-ec2-domain.com
```

### Kamal Deployment
Update your `config/deploy.yml`:

```yaml
env:
  clear:
    APP_HOST: "your-actual-ec2-domain.com"
    # ... other environment variables
```

### Systemd Service
If using systemd, add to your service file:

```ini
[Service]
Environment=APP_HOST=your-actual-ec2-domain.com
```

## Verification

After deployment, test the WhatsApp sharing feature:

1. Navigate to an invoice
2. Try to share via WhatsApp
3. Check that the public URL is generated correctly
4. Verify the WhatsApp message contains a valid link

## Troubleshooting

If the issue persists:

1. Check Rails logs for the actual host being used:
   ```bash
   tail -f log/production.log
   ```

2. Verify environment variable is set:
   ```bash
   echo $APP_HOST
   ```

3. Check if the host is in the allowed hosts list in production.rb

4. Ensure your domain DNS is properly configured to point to your EC2 instance

## Host Options Priority

The system will use hosts in this order:
1. Explicitly passed host parameter
2. `request.host_with_port` (from the current request)
3. `Rails.application.config.action_controller.default_url_options[:host]`
4. `ENV['APP_HOST']` environment variable
5. Default fallback: `'atmanirbharfarm.work.gd'`