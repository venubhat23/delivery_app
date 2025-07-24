# Customer Authentication Implementation

## Overview
This implementation creates a separate authentication system specifically for customers, independent from the User model. Customers now have their own password authentication with password confirmation fields.

## Key Changes Made

### 1. Database Migration
- **File**: `db/migrate/20250120000001_add_password_to_customers.rb`
- Added `password_digest` field for secure password storage
- Added `email` field with unique index
- Added unique index on `phone_number`

### 2. Customer Model Updates
- **File**: `app/models/customer.rb`
- Added `has_secure_password` for password authentication
- Removed `belongs_to :user` association
- Added password validation (minimum 6 characters)
- Added password confirmation validation
- Added email and phone number validations
- Updated CSV import methods to work without user association

### 3. API Controllers Structure
- **Directory**: `app/controllers/api/v1/`
- Created `BaseController` for API authentication
- Created `AuthenticationController` for customer login/signup

### 4. JWT Authentication System
- **File**: `lib/json_web_token.rb` - JWT encoding/decoding
- **File**: `lib/exception_handler.rb` - Error handling
- **File**: `lib/message.rb` - Consistent error messages
- **File**: `app/service/customer_authorization_service.rb` - Token validation

### 5. API Endpoints

#### Customer Signup
- **POST** `/api/v1/customer_signup`
- **Parameters**:
  ```json
  {
    "name": "John Doe",
    "email": "john@example.com",
    "phone_number": "9999999999",
    "password": "password123",
    "password_confirmation": "password123",
    "address": "123 Main St",
    "latitude": 12.9716,
    "longitude": 77.5946,
    "preferred_language": "English",
    "delivery_time_preference": "Morning",
    "notification_method": "SMS"
  }
  ```
- **Response**: JWT token and customer details

#### Customer Login
- **POST** `/api/v1/customer_login`
- **Parameters**:
  ```json
  {
    "phone_number": "9999999999",
    "password": "password123"
  }
  ```
- **Response**: JWT token and customer details

#### Regenerate Token
- **POST** `/api/v1/regenerate_token`
- **Parameters**: Same as login
- **Response**: New JWT token and customer details

## Key Features

### 1. Separate Authentication
- Customers no longer depend on User model
- Independent password system
- Own JWT token system

### 2. Password Confirmation
- Required during signup
- Validates password matches confirmation
- Clear error messages for mismatches

### 3. Secure Authentication
- Uses `has_secure_password` for bcrypt hashing
- JWT tokens with expiration
- Phone number and email uniqueness validation

### 4. API-First Design
- RESTful API endpoints
- JSON responses
- Proper HTTP status codes
- Comprehensive error handling

## Security Features

1. **Password Hashing**: Uses bcrypt via `has_secure_password`
2. **JWT Tokens**: Secure token-based authentication
3. **Input Validation**: Email format, phone number format
4. **Unique Constraints**: Email and phone number uniqueness
5. **Token Expiration**: 24-hour token expiry by default

## Usage Examples

### 1. Customer Signup
```bash
curl -X POST http://localhost:3000/api/v1/customer_signup \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "phone_number": "9999999999",
    "password": "password123",
    "password_confirmation": "password123",
    "address": "123 Main St"
  }'
```

### 2. Customer Login
```bash
curl -X POST http://localhost:3000/api/v1/customer_login \
  -H "Content-Type: application/json" \
  -d '{
    "phone_number": "9999999999",
    "password": "password123"
  }'
```

### 3. Authenticated Request (example)
```bash
curl -X GET http://localhost:3000/api/v1/profile \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Migration Required

To apply these changes, run:
```bash
rails db:migrate
```

This will add the necessary password authentication fields to the customers table.

## Error Handling

The system provides comprehensive error handling for:
- Invalid credentials
- Missing tokens
- Expired tokens
- Validation errors (password too short, email format, etc.)
- Password confirmation mismatches

## Next Steps

1. Run the database migration
2. Test the API endpoints
3. Update any existing customer creation logic
4. Consider adding password reset functionality
5. Add rate limiting for authentication endpoints