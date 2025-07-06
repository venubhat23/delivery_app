# Milk Delivery API Documentation

## Overview
This is a comprehensive API documentation for the Milk Delivery System. The API is built with Ruby on Rails and provides endpoints for managing customers, products, deliveries, invoices, and analytics.

**Base URL:** `http://localhost:3000/api/v1`

## Authentication
All API endpoints require JWT authentication. Include the token in the Authorization header:
```
Authorization: Bearer YOUR_JWT_TOKEN
```

## API Endpoints

### 🔐 Authentication

#### POST /auth/login
Login with email and password.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "user@example.com",
    "role": "admin"
  }
}
```

#### POST /auth/register
Register a new user.

**Request Body:**
```json
{
  "name": "John Doe",
  "email": "user@example.com",
  "password": "password123",
  "password_confirmation": "password123",
  "phone": "1234567890",
  "role": "admin"
}
```

**Response:**
```json
{
  "message": "Registration successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "name": "John Doe",
    "email": "user@example.com",
    "role": "admin"
  }
}
```

#### DELETE /auth/logout
Logout the current user.

**Response:**
```json
{
  "message": "Logged out successfully"
}
```

### 📊 Dashboard

#### GET /dashboard
Get dashboard overview with statistics and analytics.

**Response:**
```json
{
  "data": {
    "overview": {
      "total_customers": 150,
      "total_products": 25,
      "active_delivery_people": 12,
      "pending_deliveries": 45,
      "completed_deliveries_today": 23,
      "total_revenue_this_month": 15000.50,
      "pending_invoices": 8,
      "low_stock_products": 3
    },
    "recent_activities": [
      {
        "type": "customer_created",
        "title": "New customer added: John Doe",
        "description": "Customer John Doe was added to the system",
        "timestamp": "2024-01-15T10:30:00Z",
        "icon": "user-plus"
      }
    ],
    "delivery_stats": {
      "today": {
        "total": 45,
        "completed": 23,
        "pending": 22,
        "cancelled": 0
      },
      "this_week": {
        "total": 280,
        "completed": 210,
        "pending": 70
      },
      "this_month": {
        "total": 1200,
        "completed": 950,
        "pending": 250
      }
    },
    "revenue_stats": {
      "this_month": 15000.50,
      "last_month": 13500.25,
      "growth_percentage": 11.12,
      "total_pending": 2500.00,
      "total_paid": 12500.50
    },
    "charts": {
      "daily_deliveries": {
        "2024-01-15": {
          "completed": 23,
          "pending": 22,
          "total": 45
        }
      },
      "monthly_revenue": {
        "2024-01": 15000.50,
        "2023-12": 13500.25
      },
      "product_distribution": {
        "Milk 500ml": 450,
        "Milk 1L": 300,
        "Yogurt": 150
      },
      "delivery_person_performance": {
        "John Smith": 35,
        "Jane Doe": 28,
        "Mike Johnson": 42
      }
    }
  }
}
```

### 👥 Customers

#### GET /customers
Get paginated list of customers.

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 25)
- `search` (optional): Search by name or address

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "John Doe",
      "phone_number": "1234567890",
      "address": "123 Main St, City",
      "email": "john@example.com",
      "gst_number": "GST123456789",
      "pan_number": "ABCDE1234F",
      "member_id": "MEM001",
      "latitude": 40.7128,
      "longitude": -74.0060,
      "image_url": null,
      "has_coordinates": true,
      "coordinates_string": "40.712800, -74.006000",
      "google_maps_url": "https://www.google.com/maps/search/?api=1&query=40.7128,-74.0060",
      "delivery_person": {
        "id": 2,
        "name": "Jane Smith",
        "phone": "0987654321"
      },
      "total_deliveries": 45,
      "pending_deliveries": 3,
      "completed_deliveries": 42,
      "total_invoice_amount": 2500.00,
      "pending_invoice_amount": 150.00,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 6,
    "total_count": 150
  }
}
```

#### GET /customers/:id
Get customer details.

**Response:**
```json
{
  "data": {
    "id": 1,
    "name": "John Doe",
    "phone_number": "1234567890",
    "address": "123 Main St, City",
    "email": "john@example.com",
    "gst_number": "GST123456789",
    "pan_number": "ABCDE1234F",
    "member_id": "MEM001",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "image_url": null,
    "has_coordinates": true,
    "coordinates_string": "40.712800, -74.006000",
    "google_maps_url": "https://www.google.com/maps/search/?api=1&query=40.7128,-74.0060",
    "delivery_person": {
      "id": 2,
      "name": "Jane Smith",
      "phone": "0987654321"
    },
    "total_deliveries": 45,
    "pending_deliveries": 3,
    "completed_deliveries": 42,
    "total_invoice_amount": 2500.00,
    "pending_invoice_amount": 150.00,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-15T10:30:00Z"
  }
}
```

#### POST /customers
Create a new customer.

**Request Body:**
```json
{
  "customer": {
    "name": "John Doe",
    "phone_number": "1234567890",
    "address": "123 Main St, City",
    "email": "john@example.com",
    "gst_number": "GST123456789",
    "pan_number": "ABCDE1234F",
    "member_id": "MEM001",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "image_url": null
  }
}
```

#### PUT /customers/:id
Update customer information.

**Request Body:**
```json
{
  "customer": {
    "name": "John Doe Updated",
    "phone_number": "1234567890",
    "address": "456 Oak Ave, City",
    "email": "john.updated@example.com"
  }
}
```

#### DELETE /customers/:id
Delete a customer.

**Response:**
```json
{
  "message": "Customer deleted successfully"
}
```

#### POST /customers/bulk_import
Import customers from CSV data.

**Request Body:**
```json
{
  "csv_data": "name,phone_number,address,email,gst_number,pan_number,member_id,latitude,longitude\nJohn Doe,1234567890,123 Main St,john@example.com,GST123,PAN123,MEM123,40.7128,-74.0060"
}
```

**Response:**
```json
{
  "message": "Import completed successfully",
  "data": {
    "imported_count": 1,
    "total_processed": 1,
    "errors": [],
    "skipped_rows": []
  }
}
```

#### POST /customers/validate_csv
Validate CSV data before import.

**Request Body:**
```json
{
  "csv_data": "name,phone_number,address,email\nJohn Doe,1234567890,123 Main St,john@example.com"
}
```

**Response:**
```json
{
  "valid": true,
  "headers": ["name", "phone_number", "address", "email"],
  "preview": [
    {
      "name": "John Doe",
      "phone_number": "1234567890",
      "address": "123 Main St",
      "email": "john@example.com"
    }
  ],
  "total_rows": 1
}
```

#### GET /customers/export_csv
Export customers to CSV.

**Response:**
```json
{
  "csv_data": "Name,Phone,Address,Email,GST Number,PAN Number,Member ID,Latitude,Longitude,Delivery Person,Created At\nJohn Doe,1234567890,123 Main St,john@example.com,GST123,PAN123,MEM123,40.7128,-74.0060,Jane Smith,2024-01-01",
  "filename": "customers_export_2024-01-15.csv"
}
```

#### PATCH /customers/:id/assign_delivery_person
Assign delivery person to customer.

**Request Body:**
```json
{
  "delivery_person_id": 2
}
```

#### GET /customers/:id/delivery_history
Get customer's delivery history.

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "scheduled_date": "2024-01-15",
      "status": "completed",
      "quantity": 2,
      "unit": "bottles",
      "total_amount": 100.00,
      "product": {
        "id": 1,
        "name": "Milk 1L",
        "price": 50.00
      },
      "delivery_person": {
        "id": 2,
        "name": "Jane Smith",
        "phone": "0987654321"
      },
      "completed_at": "2024-01-15T08:30:00Z",
      "created_at": "2024-01-14T10:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 2,
    "total_count": 45
  }
}
```

### 📦 Products

#### GET /products
Get paginated list of products.

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 25)
- `search` (optional): Search by name or description

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "Milk 1L",
      "description": "Fresh whole milk 1 liter",
      "unit_type": "bottles",
      "available_quantity": 500,
      "price": 50.00,
      "is_gst_applicable": true,
      "total_gst_percentage": 18.00,
      "low_stock": false,
      "out_of_stock": false,
      "stock_status": "In Stock",
      "stock_status_class": "success",
      "total_value": 25000.00,
      "formatted_price": "$50.00",
      "display_name": "Milk 1L (500 bottles)",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 1,
    "total_count": 25
  }
}
```

#### GET /products/:id
Get product details.

#### POST /products
Create a new product.

**Request Body:**
```json
{
  "product": {
    "name": "Milk 1L",
    "description": "Fresh whole milk 1 liter",
    "unit_type": "bottles",
    "available_quantity": 500,
    "price": 50.00,
    "is_gst_applicable": true,
    "total_gst_percentage": 18.00
  }
}
```

#### PUT /products/:id
Update product information.

#### DELETE /products/:id
Delete a product.

#### GET /products/low_stock
Get products with low stock levels.

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "Milk 1L",
      "available_quantity": 5,
      "price": 50.00,
      "stock_status": "Low Stock",
      "stock_status_class": "warning"
    }
  ]
}
```

### 🚚 Delivery Assignments

#### GET /delivery_assignments
Get paginated list of delivery assignments.

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 25)
- `status` (optional): Filter by status (pending, completed, cancelled)
- `delivery_person_id` (optional): Filter by delivery person
- `date` (optional): Filter by date

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "customer": {
        "id": 1,
        "name": "John Doe",
        "address": "123 Main St"
      },
      "product": {
        "id": 1,
        "name": "Milk 1L",
        "price": 50.00
      },
      "delivery_person": {
        "id": 2,
        "name": "Jane Smith",
        "phone": "0987654321"
      },
      "scheduled_date": "2024-01-15",
      "status": "pending",
      "quantity": 2,
      "unit": "bottles",
      "total_amount": 100.00,
      "invoice_generated": false,
      "created_at": "2024-01-14T10:00:00Z",
      "updated_at": "2024-01-14T10:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 10,
    "total_count": 250
  }
}
```

#### GET /delivery_assignments/:id
Get delivery assignment details.

#### POST /delivery_assignments
Create a new delivery assignment.

**Request Body:**
```json
{
  "delivery_assignment": {
    "customer_id": 1,
    "product_id": 1,
    "user_id": 2,
    "scheduled_date": "2024-01-15",
    "quantity": 2,
    "unit": "bottles"
  }
}
```

#### PUT /delivery_assignments/:id
Update delivery assignment.

#### DELETE /delivery_assignments/:id
Cancel/delete delivery assignment.

#### GET /delivery_assignments/by_delivery_person
Get assignments by delivery person.

**Query Parameters:**
- `delivery_person_id`: Required delivery person ID

#### GET /delivery_assignments/by_date
Get assignments by date.

**Query Parameters:**
- `date`: Required date (YYYY-MM-DD format)

#### POST /delivery_assignments/bulk_create
Create multiple delivery assignments.

**Request Body:**
```json
{
  "assignments": [
    {
      "customer_id": 1,
      "product_id": 1,
      "user_id": 2,
      "scheduled_date": "2024-01-15",
      "quantity": 2,
      "unit": "bottles"
    },
    {
      "customer_id": 2,
      "product_id": 1,
      "user_id": 2,
      "scheduled_date": "2024-01-15",
      "quantity": 1,
      "unit": "bottles"
    }
  ]
}
```

#### PATCH /delivery_assignments/:id/update_status
Update delivery assignment status.

**Request Body:**
```json
{
  "status": "completed"
}
```

#### PATCH /delivery_assignments/:id/complete
Mark delivery assignment as completed.

#### PATCH /delivery_assignments/:id/cancel
Cancel delivery assignment.

### 📋 Delivery Schedules

#### GET /delivery_schedules
Get paginated list of delivery schedules.

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "customer": {
        "id": 1,
        "name": "John Doe"
      },
      "product": {
        "id": 1,
        "name": "Milk 1L"
      },
      "frequency": "daily",
      "start_date": "2024-01-01",
      "end_date": "2024-01-31",
      "status": "active",
      "default_quantity": 2,
      "default_unit": "bottles",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 3,
    "total_count": 75
  }
}
```

#### GET /delivery_schedules/:id
Get delivery schedule details.

#### POST /delivery_schedules
Create a new delivery schedule.

**Request Body:**
```json
{
  "delivery_schedule": {
    "customer_id": 1,
    "product_id": 1,
    "frequency": "daily",
    "start_date": "2024-01-01",
    "end_date": "2024-01-31",
    "default_quantity": 2,
    "default_unit": "bottles"
  }
}
```

#### PUT /delivery_schedules/:id
Update delivery schedule.

#### DELETE /delivery_schedules/:id
Delete delivery schedule.

#### PATCH /delivery_schedules/:id/activate
Activate delivery schedule.

#### PATCH /delivery_schedules/:id/deactivate
Deactivate delivery schedule.

#### GET /delivery_schedules/:id/assignments
Get assignments for a specific schedule.

### 🧾 Invoices

#### GET /invoices
Get paginated list of invoices.

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `per_page` (optional): Items per page (default: 25)
- `status` (optional): Filter by status (pending, paid, overdue)
- `customer_id` (optional): Filter by customer

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "invoice_number": "INV-2024-001",
      "customer": {
        "id": 1,
        "name": "John Doe"
      },
      "invoice_date": "2024-01-15",
      "due_date": "2024-01-30",
      "total_amount": 500.00,
      "status": "pending",
      "invoice_type": "monthly",
      "items": [
        {
          "id": 1,
          "product": {
            "id": 1,
            "name": "Milk 1L"
          },
          "quantity": 10,
          "unit_price": 50.00,
          "total_price": 500.00
        }
      ],
      "created_at": "2024-01-15T10:00:00Z",
      "updated_at": "2024-01-15T10:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 5,
    "total_count": 125
  }
}
```

#### GET /invoices/:id
Get invoice details.

#### POST /invoices
Create a new invoice.

**Request Body:**
```json
{
  "invoice": {
    "customer_id": 1,
    "invoice_date": "2024-01-15",
    "due_date": "2024-01-30",
    "invoice_type": "monthly",
    "items": [
      {
        "product_id": 1,
        "quantity": 10,
        "unit_price": 50.00
      }
    ]
  }
}
```

#### PUT /invoices/:id
Update invoice.

#### DELETE /invoices/:id
Delete invoice.

#### GET /invoices/generate_monthly
Generate monthly invoices for all customers.

#### POST /invoices/generate_for_customer
Generate invoice for specific customer.

**Request Body:**
```json
{
  "customer_id": 1,
  "month": 1,
  "year": 2024
}
```

#### GET /invoices/analytics
Get invoice analytics.

**Response:**
```json
{
  "data": {
    "total_invoices": 125,
    "total_amount": 62500.00,
    "pending_amount": 15000.00,
    "paid_amount": 47500.00,
    "overdue_amount": 5000.00,
    "monthly_breakdown": {
      "2024-01": 15000.00,
      "2023-12": 14500.00,
      "2023-11": 13000.00
    }
  }
}
```

#### PATCH /invoices/:id/mark_as_paid
Mark invoice as paid.

#### GET /invoices/:id/download_pdf
Download invoice as PDF.

### 🛒 Purchase Management

#### GET /purchase_products
Get paginated list of purchase products.

#### GET /purchase_products/:id
Get purchase product details.

#### POST /purchase_products
Create a new purchase product.

#### PUT /purchase_products/:id
Update purchase product.

#### DELETE /purchase_products/:id
Delete purchase product.

#### GET /purchase_invoices
Get paginated list of purchase invoices.

#### GET /purchase_invoices/:id
Get purchase invoice details.

#### POST /purchase_invoices
Create a new purchase invoice.

#### PUT /purchase_invoices/:id
Update purchase invoice.

#### DELETE /purchase_invoices/:id
Delete purchase invoice.

#### PATCH /purchase_invoices/:id/mark_as_paid
Mark purchase invoice as paid.

#### GET /purchase_invoices/:id/download_pdf
Download purchase invoice as PDF.

### 💰 Sales Management

#### GET /sales_products
Get paginated list of sales products.

#### GET /sales_products/:id
Get sales product details.

#### POST /sales_products
Create a new sales product.

#### PUT /sales_products/:id
Update sales product.

#### DELETE /sales_products/:id
Delete sales product.

#### GET /sales_invoices
Get paginated list of sales invoices.

#### GET /sales_invoices/:id
Get sales invoice details.

#### POST /sales_invoices
Create a new sales invoice.

#### PUT /sales_invoices/:id
Update sales invoice.

#### DELETE /sales_invoices/:id
Delete sales invoice.

#### PATCH /sales_invoices/:id/mark_as_paid
Mark sales invoice as paid.

#### GET /sales_invoices/:id/download_pdf
Download sales invoice as PDF.

### 👨‍💼 Users (Delivery People)

#### GET /users
Get paginated list of users.

**Query Parameters:**
- `role` (optional): Filter by role (admin, delivery_person)

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "phone": "1234567890",
      "role": "delivery_person",
      "assigned_customers_count": 15,
      "completed_deliveries_count": 245,
      "created_at": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 2,
    "total_count": 35
  }
}
```

#### GET /users/:id
Get user details.

#### POST /users
Create a new user.

#### PUT /users/:id
Update user information.

#### DELETE /users/:id
Delete user.

#### GET /delivery_people/:id/assigned_customers
Get customers assigned to delivery person.

#### PATCH /delivery_people/:id/assign_customers
Assign customers to delivery person.

**Request Body:**
```json
{
  "customer_ids": [1, 2, 3, 4, 5]
}
```

#### GET /delivery_people/:id/delivery_statistics
Get delivery statistics for delivery person.

**Response:**
```json
{
  "data": {
    "total_assignments": 150,
    "completed_deliveries": 145,
    "pending_deliveries": 5,
    "success_rate": 96.67,
    "assigned_customers": 15,
    "monthly_performance": {
      "2024-01": {
        "completed": 45,
        "pending": 5,
        "cancelled": 0
      }
    }
  }
}
```

### 📊 Analytics

#### GET /analytics/dashboard
Get comprehensive dashboard analytics.

#### GET /analytics/delivery_performance
Get delivery performance analytics.

**Response:**
```json
{
  "data": {
    "overall_performance": {
      "total_deliveries": 1250,
      "completed_deliveries": 1180,
      "pending_deliveries": 70,
      "cancelled_deliveries": 0,
      "success_rate": 94.4
    },
    "monthly_trends": {
      "2024-01": {
        "total": 450,
        "completed": 420,
        "pending": 30,
        "success_rate": 93.33
      }
    },
    "delivery_person_performance": [
      {
        "name": "John Smith",
        "completed": 145,
        "pending": 5,
        "success_rate": 96.67
      }
    ]
  }
}
```

#### GET /analytics/customer_analytics
Get customer analytics.

**Response:**
```json
{
  "data": {
    "total_customers": 150,
    "active_customers": 135,
    "new_customers_this_month": 15,
    "customer_retention_rate": 92.5,
    "top_customers": [
      {
        "name": "John Doe",
        "total_orders": 45,
        "total_amount": 2250.00
      }
    ],
    "customer_growth": {
      "2024-01": 15,
      "2023-12": 12,
      "2023-11": 18
    }
  }
}
```

#### GET /analytics/revenue_analytics
Get revenue analytics.

**Response:**
```json
{
  "data": {
    "total_revenue": 125000.00,
    "monthly_revenue": 15000.00,
    "average_order_value": 85.50,
    "growth_rate": 12.5,
    "revenue_by_product": {
      "Milk 1L": 75000.00,
      "Milk 500ml": 35000.00,
      "Yogurt": 15000.00
    },
    "monthly_trends": {
      "2024-01": 15000.00,
      "2023-12": 13500.00,
      "2023-11": 12000.00
    }
  }
}
```

#### GET /analytics/product_analytics
Get product analytics.

**Response:**
```json
{
  "data": {
    "total_products": 25,
    "low_stock_products": 3,
    "out_of_stock_products": 0,
    "top_selling_products": [
      {
        "name": "Milk 1L",
        "total_sold": 1500,
        "revenue": 75000.00
      }
    ],
    "product_performance": {
      "Milk 1L": {
        "total_sold": 1500,
        "revenue": 75000.00,
        "growth_rate": 15.2
      }
    }
  }
}
```

### 🏥 Health Check

#### GET /health
Check API health status.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0"
}
```

## Error Responses

All endpoints may return the following error responses:

### 400 Bad Request
```json
{
  "error": "Bad request",
  "details": "Invalid parameters provided"
}
```

### 401 Unauthorized
```json
{
  "error": "Access denied"
}
```

### 404 Not Found
```json
{
  "error": "Resource not found"
}
```

### 422 Unprocessable Entity
```json
{
  "errors": [
    "Name can't be blank",
    "Email is invalid"
  ]
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error"
}
```

## Pagination

All list endpoints support pagination with the following query parameters:
- `page`: Page number (default: 1)
- `per_page`: Items per page (default: 25, max: 100)

Pagination information is included in the response:
```json
{
  "data": [...],
  "pagination": {
    "current_page": 1,
    "per_page": 25,
    "total_pages": 10,
    "total_count": 250
  }
}
```

## Filtering and Searching

Many endpoints support filtering and searching:
- `search`: Search term for text fields
- `filter_by`: Field to filter by
- `filter_value`: Value to filter by
- `sort_by`: Field to sort by
- `sort_order`: Sort order (asc/desc)

## Rate Limiting

The API implements rate limiting to prevent abuse:
- 100 requests per minute per IP address
- 1000 requests per hour per authenticated user

Rate limit information is included in response headers:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1642248000
```

## Webhooks

The API supports webhooks for real-time notifications:
- `delivery.completed`: Fired when a delivery is completed
- `invoice.created`: Fired when an invoice is created
- `customer.created`: Fired when a customer is created

Webhook payloads include the relevant data and a signature for verification.

## SDK and Libraries

Official SDKs are available for:
- JavaScript/TypeScript
- Python
- PHP
- Java

## Support

For API support, please contact:
- Email: api-support@milkdelivery.com
- Documentation: https://docs.milkdelivery.com
- Status Page: https://status.milkdelivery.com