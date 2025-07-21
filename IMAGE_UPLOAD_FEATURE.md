# Image Upload Feature Implementation

## Overview
This implementation adds image upload functionality to both Products and Customers in your Rails admin application, similar to the external API you referenced.

## Features Implemented

### 1. File Upload API Endpoint
- **Route**: `POST /api/upload`
- **Controller**: `UploadsController#create`
- **Functionality**: Handles file uploads with validation and storage

### 2. Product Image Support
- Added `image_url` parameter to product forms
- Updated Products controller to handle image uploads
- Enhanced product index view to display images
- Added image upload UI to product forms

### 3. Customer Image Support
- Added `image_url` parameter to customer forms (already existed in schema)
- Updated customer forms with image upload UI
- Enhanced customer index view to display profile photos

## Technical Implementation

### Backend (Rails)

#### 1. Uploads Controller (`app/controllers/uploads_controller.rb`)
```ruby
class UploadsController < ApplicationController
  before_action :require_login
  
  def create
    # File validation (type, size)
    # Secure filename generation
    # File storage in public/uploads/images/
    # Returns JSON with file URL
  end
end
```

**Features:**
- File type validation (images only)
- File size validation (max 5MB)
- Secure filename generation with timestamp and random string
- Automatic directory creation
- JSON response with file URL

#### 2. Updated Controllers
- **ProductsController**: Added `image_url` to permitted parameters
- **CustomersController**: Already had `image_url` support

#### 3. Routes
```ruby
# File Upload API
post '/api/upload', to: 'uploads#create'
```

### Frontend (Views & JavaScript)

#### 1. Product Form (`app/views/products/_form.html.erb`)
- Drag & drop upload area
- Image preview functionality
- Progress indicator during upload
- Remove image functionality
- Real-time upload with AJAX

#### 2. Customer Form (`app/views/customers/_form.html.erb`)
- Similar upload interface as products
- Optimized for profile photos (circular preview)

#### 3. Index Views
- **Products**: Square thumbnails (50x50px) with hover effects
- **Customers**: Circular profile photos (50x50px)
- Fallback placeholders for items without images

## File Storage Structure

```
public/
└── uploads/
    └── images/
        ├── .gitkeep
        └── [uploaded files with unique names]
```

**File Naming Convention:**
`{timestamp}_{random_string}.{extension}`

Example: `1704067200_a1b2c3d4.jpg`

## Security Features

1. **File Type Validation**: Only image files allowed (JPEG, PNG, GIF, WebP)
2. **File Size Limits**: Maximum 5MB per file
3. **Secure Filename Generation**: Prevents directory traversal attacks
4. **Authentication Required**: Only logged-in users can upload
5. **Unique Filenames**: Prevents conflicts and overwrites

## Usage Instructions

### For Products:
1. Go to Products → Add Product or edit existing product
2. Scroll to "Product Image" section
3. Click the upload area or drag & drop an image
4. Wait for upload completion
5. Save the product

### For Customers:
1. Go to Customers → Add Customer or edit existing customer
2. Scroll to "Customer Photo" section
3. Click the upload area or drag & drop an image
4. Wait for upload completion
5. Save the customer

## API Response Format

### Success Response:
```json
{
  "url": "http://your-domain.com/uploads/images/1704067200_a1b2c3d4.jpg",
  "filename": "1704067200_a1b2c3d4.jpg",
  "size": 1234567,
  "content_type": "image/jpeg"
}
```

### Error Responses:
```json
{
  "error": "No file provided"
}
```

```json
{
  "error": "Invalid file type. Only images are allowed."
}
```

```json
{
  "error": "File size too large. Maximum 5MB allowed."
}
```

## Database Schema

Both `products` and `customers` tables already have the `image_url` column:

```sql
-- Products table
ALTER TABLE products ADD COLUMN image_url VARCHAR(255);

-- Customers table (already exists)
ALTER TABLE customers ADD COLUMN image_url VARCHAR(255);
```

## JavaScript Features

### Upload Functionality:
- Drag & drop support
- File type validation
- File size validation
- Progress indication
- Error handling
- Success notifications
- Image preview
- Remove image functionality

### Toast Notifications:
- Success: Green notification with checkmark
- Error: Red notification with error icon
- Auto-dismiss after 5 seconds
- Manual dismiss option

## CSS Styling

### Upload Areas:
- Dashed border with hover effects
- Responsive design
- Visual feedback for drag & drop
- Loading states
- Preview containers

### Image Displays:
- **Products**: Square thumbnails with rounded corners
- **Customers**: Circular profile photos
- Hover effects and transitions
- Consistent sizing across views

## Integration with Your External API

The implementation mimics your external API structure:
- Same endpoint pattern (`/api/upload`)
- Similar response format
- File validation approach
- Error handling patterns

## Future Enhancements

1. **Image Resizing**: Automatic thumbnail generation
2. **Cloud Storage**: Integration with AWS S3 or similar
3. **Multiple Images**: Support for image galleries
4. **Image Optimization**: Compression and format conversion
5. **Bulk Upload**: Multiple file selection
6. **Image Editing**: Basic cropping and filters

## Testing

To test the implementation:

1. Start your Rails server
2. Navigate to Products or Customers
3. Try uploading various file types (should only accept images)
4. Try uploading large files (should reject >5MB)
5. Verify images appear in index views
6. Check uploaded files in `public/uploads/images/`

## Troubleshooting

### Common Issues:

1. **Upload fails**: Check file permissions on `public/uploads/images/`
2. **Images don't display**: Verify the web server serves static files from `public/`
3. **Large files rejected**: This is expected behavior (5MB limit)
4. **JavaScript errors**: Check browser console for CSRF token issues

### File Permissions:
```bash
chmod 755 public/uploads/images/
```

## Configuration

The upload directory and size limits can be modified in `app/controllers/uploads_controller.rb`:

```ruby
# Change upload directory
upload_dir = Rails.root.join('public', 'uploads', 'images')

# Change size limit (currently 5MB)
if file.size > 5.megabytes
```

This implementation provides a complete, secure, and user-friendly image upload system for your Rails admin application.