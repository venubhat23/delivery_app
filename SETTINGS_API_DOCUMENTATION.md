# Settings API Documentation

This documentation covers the Settings API endpoints for user account management, timezone settings, and account deletion functionality.

## Base URL
```
/api/settings
```

## Authentication
All Settings API endpoints require user authentication. The user must be logged in with a valid session.

## Endpoints

### 1. Get Available Timezones

**Endpoint:** `GET /api/settings/timezones`

**Description:** Retrieve a list of available timezones for the user to select from.

**Request:**
```http
GET /api/settings/timezones
Content-Type: application/json
```

**Response:**
```json
{
  "success": true,
  "data": {
    "timezones": [
      {
        "value": "Asia/Kolkata",
        "label": "Asia/Kolkata",
        "offset": "+05:30"
      },
      {
        "value": "Asia/Mumbai",
        "label": "Asia/Mumbai", 
        "offset": "+05:30"
      },
      {
        "value": "Asia/Delhi",
        "label": "Asia/Delhi",
        "offset": "+05:30"
      },
      {
        "value": "Asia/Chennai",
        "label": "Asia/Chennai",
        "offset": "+05:30"
      },
      {
        "value": "Asia/Bangalore",
        "label": "Asia/Bangalore",
        "offset": "+05:30"
      },
      {
        "value": "UTC",
        "label": "UTC",
        "offset": "+00:00"
      },
      {
        "value": "America/New_York",
        "label": "America/New York",
        "offset": "-05:00"
      },
      {
        "value": "Europe/London",
        "label": "Europe/London",
        "offset": "+00:00"
      },
      {
        "value": "Asia/Tokyo",
        "label": "Asia/Tokyo",
        "offset": "+09:00"
      },
      {
        "value": "Australia/Sydney",
        "label": "Australia/Sydney",
        "offset": "+11:00"
      }
    ],
    "current_timezone": "Asia/Kolkata"
  }
}
```

### 2. Get Current User Timezone

**Endpoint:** `GET /api/settings/timezone`

**Description:** Get the current user's timezone setting and current time in that timezone.

**Request:**
```http
GET /api/settings/timezone
Content-Type: application/json
```

**Response:**
```json
{
  "success": true,
  "data": {
    "timezone": "Asia/Kolkata",
    "timezone_label": "Asia/Kolkata",
    "offset": "+05:30",
    "current_time": "2024-07-22 18:45:30 IST"
  }
}
```

### 3. Update User Timezone

**Endpoint:** `PUT /api/settings/timezone`

**Description:** Update the user's timezone setting.

**Request:**
```http
PUT /api/settings/timezone
Content-Type: application/json

{
  "timezone": "Asia/Mumbai"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Timezone updated successfully",
  "data": {
    "timezone": "Asia/Mumbai",
    "current_time": "2024-07-22 18:45:30 IST"
  }
}
```

**Response (Error - Invalid Timezone):**
```json
{
  "success": false,
  "error": "Invalid timezone selected",
  "available_timezones": [
    "Asia/Kolkata",
    "Asia/Mumbai",
    "Asia/Delhi",
    "Asia/Chennai",
    "Asia/Bangalore",
    "UTC",
    "America/New_York",
    "Europe/London",
    "Asia/Tokyo",
    "Australia/Sydney"
  ]
}
```

### 4. Get User Profile

**Endpoint:** `GET /api/settings/profile`

**Description:** Get current user's profile information for settings.

**Request:**
```http
GET /api/settings/profile
Content-Type: application/json
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+91-9876543210",
    "role": "user",
    "timezone": "Asia/Kolkata",
    "created_at": "2024-07-01T10:30:00.000Z",
    "updated_at": "2024-07-22T13:15:30.000Z"
  }
}
```

### 5. Update User Profile

**Endpoint:** `PUT /api/settings/profile`

**Description:** Update user profile information (name, phone, timezone).

**Request:**
```http
PUT /api/settings/profile
Content-Type: application/json

{
  "user": {
    "name": "John Smith",
    "phone": "+91-9876543211",
    "timezone": "Asia/Delhi"
  }
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Profile updated successfully",
  "data": {
    "id": 1,
    "name": "John Smith",
    "email": "john@example.com",
    "phone": "+91-9876543211",
    "timezone": "Asia/Delhi"
  }
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Failed to update profile",
  "errors": [
    "Name can't be blank",
    "Phone can't be blank"
  ]
}
```

### 6. Delete User Account

**Endpoint:** `DELETE /api/settings/account`

**Description:** Soft delete the user's account. This requires password confirmation and will deactivate the account.

**Request:**
```http
DELETE /api/settings/account
Content-Type: application/json

{
  "password": "user_current_password"
}
```

**Response (Success):**
```json
{
  "success": true,
  "message": "Your account has been successfully deleted. We're sorry to see you go!"
}
```

**Response (Error - Invalid Password):**
```json
{
  "success": false,
  "error": "Invalid password. Please enter your current password to delete your account."
}
```

**Response (Error - Server Error):**
```json
{
  "success": false,
  "error": "Failed to delete account. Please try again or contact support.",
  "details": "Database connection error"
}
```

## Error Responses

### Common Error Responses

**401 Unauthorized (Not logged in):**
```json
{
  "success": false,
  "error": "User not found"
}
```

**422 Unprocessable Entity (Validation Error):**
```json
{
  "success": false,
  "error": "Validation failed",
  "errors": ["Field can't be blank"]
}
```

**500 Internal Server Error:**
```json
{
  "success": false,
  "error": "Internal server error",
  "details": "Error message"
}
```

## Usage Examples

### JavaScript/Fetch API Examples

#### Get Available Timezones
```javascript
fetch('/api/settings/timezones', {
  method: 'GET',
  headers: {
    'Content-Type': 'application/json',
  },
  credentials: 'include' // Include cookies for session
})
.then(response => response.json())
.then(data => {
  if (data.success) {
    const timezones = data.data.timezones;
    // Populate dropdown with timezones
    timezones.forEach(tz => {
      console.log(`${tz.label} (${tz.offset})`);
    });
  }
});
```

#### Update Timezone
```javascript
fetch('/api/settings/timezone', {
  method: 'PUT',
  headers: {
    'Content-Type': 'application/json',
  },
  credentials: 'include',
  body: JSON.stringify({
    timezone: 'Asia/Mumbai'
  })
})
.then(response => response.json())
.then(data => {
  if (data.success) {
    alert('Timezone updated successfully!');
  } else {
    alert('Error: ' + data.error);
  }
});
```

#### Delete Account
```javascript
const password = prompt('Enter your password to delete account:');

fetch('/api/settings/account', {
  method: 'DELETE',
  headers: {
    'Content-Type': 'application/json',
  },
  credentials: 'include',
  body: JSON.stringify({
    password: password
  })
})
.then(response => response.json())
.then(data => {
  if (data.success) {
    alert(data.message);
    // Redirect to login page
    window.location.href = '/login';
  } else {
    alert('Error: ' + data.error);
  }
});
```

### cURL Examples

#### Get Timezones
```bash
curl -X GET \
  -H "Content-Type: application/json" \
  -b "cookie_file" \
  http://localhost:3000/api/settings/timezones
```

#### Update Timezone
```bash
curl -X PUT \
  -H "Content-Type: application/json" \
  -b "cookie_file" \
  -d '{"timezone": "Asia/Mumbai"}' \
  http://localhost:3000/api/settings/timezone
```

#### Delete Account
```bash
curl -X DELETE \
  -H "Content-Type: application/json" \
  -b "cookie_file" \
  -d '{"password": "user_password"}' \
  http://localhost:3000/api/settings/account
```

## Frontend Implementation Guide

### HTML Dropdown for Timezone Selection

```html
<div class="timezone-selector">
  <label for="timezone">Select Timezone:</label>
  <select id="timezone" name="timezone">
    <option value="">Loading...</option>
  </select>
  <button onclick="updateTimezone()">Update Timezone</button>
</div>

<script>
// Load timezones on page load
document.addEventListener('DOMContentLoaded', function() {
  loadTimezones();
});

function loadTimezones() {
  fetch('/api/settings/timezones')
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        const select = document.getElementById('timezone');
        select.innerHTML = '';
        
        data.data.timezones.forEach(tz => {
          const option = document.createElement('option');
          option.value = tz.value;
          option.textContent = `${tz.label} (${tz.offset})`;
          
          if (tz.value === data.data.current_timezone) {
            option.selected = true;
          }
          
          select.appendChild(option);
        });
      }
    });
}

function updateTimezone() {
  const timezone = document.getElementById('timezone').value;
  
  fetch('/api/settings/timezone', {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
    },
    credentials: 'include',
    body: JSON.stringify({ timezone: timezone })
  })
  .then(response => response.json())
  .then(data => {
    if (data.success) {
      alert('Timezone updated successfully!');
    } else {
      alert('Error: ' + data.error);
    }
  });
}
</script>
```

## Notes

1. **Default Timezone**: New users are automatically assigned `Asia/Kolkata` as their default timezone.

2. **Soft Delete**: Account deletion is implemented as a soft delete, meaning the user record is not physically removed from the database but marked as inactive.

3. **Session Management**: After account deletion, the user's session is automatically cleared.

4. **Timezone Validation**: Only predefined timezones are accepted to ensure consistency.

5. **Password Confirmation**: Account deletion requires the user's current password for security.

6. **Error Handling**: All endpoints provide detailed error messages for better debugging and user experience.

## Migration Commands

To apply the database changes, run these migrations:

```bash
# Add timezone field to users table
rails db:migrate

# The migrations will add:
# - timezone:string field with default 'Asia/Kolkata'
# - is_active:boolean field with default true
# - Index on is_active field
```

## Testing the API

You can test the API endpoints using tools like:
- Postman
- cURL
- Browser Developer Tools
- Rails Console

Make sure to include proper authentication cookies or session data when testing.