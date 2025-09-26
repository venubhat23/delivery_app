# Twilio SMS Configuration Guide

## Overview
This guide explains how to configure Twilio SMS notifications for mobile orders and subscriptions in your delivery management system.

## Features Implemented
✅ SMS notifications to owner when customers place orders via mobile app
✅ SMS notifications to owner when customers create subscriptions via mobile app
✅ Email notifications to owner for both orders and subscriptions
✅ Only triggers for mobile bookings (booked_by == 1)

## Twilio Setup

### 1. Create Twilio Account
1. Go to [https://www.twilio.com](https://www.twilio.com)
2. Sign up for a free account
3. Verify your phone number

### 2. Get Your Credentials
Once logged in to your Twilio Console:
1. **Account SID**: Found on your Twilio Console Dashboard
2. **Auth Token**: Found on your Twilio Console Dashboard (click to reveal)
3. **Phone Number**:
   - Go to Phone Numbers > Manage > Active numbers
   - If you don't have one, buy a phone number from Twilio

### 3. Configure Environment Variables

Add these to your `.env` file or Rails credentials:

```bash
# Option 1: Using environment variables (.env file)
TWILIO_ACCOUNT_SID=your_account_sid_here
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_FROM_NUMBER=+1234567890  # Your Twilio phone number

# Option 2: Using Rails credentials (recommended for production)
# Run: rails credentials:edit
```

For Rails credentials, add:
```yaml
twilio_account_sid: your_account_sid_here
twilio_auth_token: your_auth_token_here
twilio_from_number: +1234567890
```

## Email Configuration

Make sure your email is configured in `config/environments/production.rb`:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: 'smtp.gmail.com',
  port: 587,
  domain: 'yourdomain.com',
  user_name: 'your_email@gmail.com',
  password: 'your_app_password',
  authentication: :plain,
  enable_starttls_auto: true
}
```

## Owner Contact Configuration

1. Go to Admin Settings in your application
2. Set the owner's email and mobile number
3. These will be used for notifications

## How It Works

### For Orders (Mobile App)
When a customer places an order via mobile app (`booking_done_by: "customer"`):
1. SMS sent to owner with order details
2. Email sent to owner with complete order information

### For Subscriptions (Mobile App)
When a customer creates a subscription via mobile app (`booking_done_by: "customer"`):
1. SMS sent to owner with subscription details
2. Email sent to owner with complete subscription information

### Sample SMS Messages

**Order SMS:**
```
🛒 New Order Alert!
Customer: John Doe
Items: 3
Source: Mobile App
Please check your dashboard.
```

**Subscription SMS:**
```
📅 New Subscription Alert!
Customer: Jane Smith
Period: 01/01/2024 - 31/01/2024
Source: Mobile App
Please check your dashboard.
```

## Testing

### Test SMS Locally
```ruby
# Rails console
sms = SmsService.new
sms.send_owner_notification(:order, "Test Customer", 2)
```

### Test Email Locally
```ruby
# Rails console
OwnerNotificationMailer.new_mobile_order(
  "Test Customer",
  {
    order_date: Date.current,
    items_count: 2,
    delivery_person: "Delivery Person Name",
    items: [{product_name: "Milk", quantity: 2, unit: "liters"}]
  }
).deliver_now
```

## Pricing (Twilio)

- **SMS**: $0.0075 per SMS in India, $0.0075 per SMS in US
- **Free Trial**: $15.50 in free credit when you sign up
- **Phone Number**: ~$1/month for a phone number

## Troubleshooting

### SMS Not Sending
1. Check Twilio credentials are correct
2. Verify phone number format (should include country code)
3. Check Twilio Console logs for delivery status
4. Ensure sufficient balance in Twilio account

### Email Not Sending
1. Check email configuration in environment files
2. Verify AdminSetting has owner email set
3. Check Rails logs for error messages

## Important Notes

- Notifications only send for mobile bookings (`booked_by == 1`)
- Admin bookings (`booked_by == 0`) and delivery person bookings (`booked_by == 2`) do NOT trigger notifications
- Phone numbers are automatically formatted with +91 country code (India) if not specified
- All errors are logged to Rails.logger for debugging

## Files Modified/Created

1. `app/services/sms_service.rb` - Twilio SMS service
2. `app/mailers/owner_notification_mailer.rb` - Email notifications
3. `app/views/owner_notification_mailer/` - Email templates
4. `app/models/admin_setting.rb` - Owner contact methods
5. `app/controllers/api/v1/orders_controller.rb` - Order notifications
6. `app/controllers/api/v1/subscriptions_controller.rb` - Subscription notifications