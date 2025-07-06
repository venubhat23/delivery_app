# Admin Settings Implementation

This document describes the implementation of the Admin Settings feature for the Rails Delivery Management System.

## Features Implemented

### 1. Business Details Section
- **Business Name**: Atma Nirbhar Farm (default value)
- **Address**: Multi-line address input
- **Mobile**: Contact phone number
- **Email**: Business email with validation
- **GSTIN**: GST identification number
- **PAN Number**: Tax identification number

### 2. Bank Details Section
- **Account Holder Name**: Atma Nirbhar Farm (default value)
- **Bank Name**: Canara Bank (default value)
- **Account Number**: 3194201000718 (default value)
- **IFSC Code**: CNRB0003194 (default value)

### 3. UPI Payment Section
- **UPI ID**: Input field for UPI identifier
- **QR Code Generation**: Automatic QR code generation using the `rqrcode` gem
- **QR Code Display**: Shows generated QR code in the UI
- **Copy to Clipboard**: JavaScript functionality to copy UPI ID
- **Download QR Code**: Direct download link for QR code
- **Share QR Code**: Web Share API integration (where supported)

### 4. Terms and Conditions Section
- **Terms Text**: Default payment terms with monthly payment instructions
- **Formatted Display**: Multi-line text display with proper formatting

## Technical Implementation

### Backend Components

1. **AdminSetting Model** (`app/models/admin_setting.rb`)
   - Validations for required fields
   - Email format validation
   - UPI ID format validation
   - Helper method for formatted terms display

2. **AdminSettingsController** (`app/controllers/admin_settings_controller.rb`)
   - Full CRUD operations (Create, Read, Update, Delete)
   - QR code generation using RQRCode gem
   - File storage in `public/qr_codes/` directory
   - Default values assignment for new records

3. **Database Migration** (`db/migrate/20250706122414_create_admin_settings.rb`)
   - Complete table structure with all required fields
   - Proper field types (string, text, etc.)

### Frontend Components

1. **Views Directory** (`app/views/admin_settings/`)
   - `index.html.erb`: Main admin settings page
   - `show.html.erb`: Display view with all sections
   - `new.html.erb`: Setup new admin settings
   - `edit.html.erb`: Edit existing settings
   - `_form.html.erb`: Shared form partial

2. **UI Features**
   - Bootstrap-based responsive design
   - Card-based layout for different sections
   - Form validation with visual feedback
   - Icon-based navigation and actions
   - JavaScript for clipboard and sharing functionality

### Routes Configuration

```ruby
# Admin Settings
resources :admin_settings, path: 'admin-settings'
```

### Navigation Integration

Added to the main sidebar navigation:
- Icon: Settings (fas fa-cog)
- Link: Admin Settings
- Active state highlighting

## Default Values

When setting up for the first time, the following default values are pre-populated:

```ruby
business_name: "Atma Nirbhar Farm"
account_holder_name: "Atma Nirbhar Farm"
bank_name: "Canara Bank"
account_number: "3194201000718"
ifsc_code: "CNRB0003194"
terms_and_conditions: "Kindly make your monthly payment on or before the 10th of every month.
Please share the payment screenshot immediately after completing the transaction to confirm your payment."
```

## QR Code Generation

- Uses the `rqrcode` gem for QR code generation
- Generates SVG format QR codes
- Stores QR codes in `public/qr_codes/` directory
- Automatic generation when UPI ID is provided
- File naming convention: `upi_qr_#{admin_setting.id}.svg`

## Usage Instructions

1. **First Time Setup**:
   - Navigate to Admin Settings from the sidebar
   - Click "Setup Settings" button
   - Fill in all required fields
   - Save to create the initial configuration

2. **Viewing Settings**:
   - Access through sidebar navigation
   - View all configured sections
   - Copy UPI ID to clipboard
   - Download or share QR code

3. **Updating Settings**:
   - Click "Edit Settings" button
   - Modify any field as needed
   - QR code regenerates automatically if UPI ID changes
   - Save changes to update

## Files Created/Modified

### New Files Created:
- `app/models/admin_setting.rb`
- `app/controllers/admin_settings_controller.rb`
- `app/views/admin_settings/index.html.erb`
- `app/views/admin_settings/show.html.erb`
- `app/views/admin_settings/new.html.erb`
- `app/views/admin_settings/edit.html.erb`
- `app/views/admin_settings/_form.html.erb`
- `db/migrate/20250706122414_create_admin_settings.rb`
- `public/qr_codes/` directory

### Modified Files:
- `config/routes.rb` - Added admin_settings routes
- `app/views/layouts/application.html.erb` - Added navigation link
- `Gemfile` - Added `rqrcode` gem
- `db/seeds.rb` - Added default admin settings

## Dependencies

- `rqrcode` gem for QR code generation
- Bootstrap for UI components
- Font Awesome for icons
- PostgreSQL for database storage

## Testing

The application includes:
- Model validations
- Controller actions
- View rendering
- QR code generation
- File storage
- Navigation integration

All features have been tested and are working correctly with the default configuration.