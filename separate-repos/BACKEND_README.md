# Milk Delivery API Backend

A Rails API-only backend for managing milk delivery operations with JWT authentication and comprehensive endpoints.

## 🚀 Features

- **API-Only Architecture** - Pure Rails API without views
- **JWT Authentication** - Secure token-based authentication
- **CORS Support** - Ready for frontend integration
- **Comprehensive Endpoints** - 70+ API endpoints
- **Database Management** - PostgreSQL with migrations
- **Business Logic** - Complete milk delivery workflow

## 🛠️ Technology Stack

- **Ruby on Rails 8** - API-only mode
- **PostgreSQL** - Primary database
- **JWT** - Authentication tokens
- **Rack-CORS** - Cross-origin requests
- **BCrypt** - Password encryption
- **Puma** - Web server

## 📋 Prerequisites

- Ruby 3.0 or higher
- Rails 8.0 or higher
- PostgreSQL 12 or higher
- Git

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Extract the backend files
tar -xzf milk-delivery-backend.tar.gz
cd milk-delivery-backend

# Install dependencies
bundle install

# Setup database
rails db:create
rails db:migrate
rails db:seed

# Start the server
rails server
```

### 2. Environment Configuration

Create a `.env` file:

```env
DATABASE_URL=postgresql://username:password@localhost/milk_delivery_development
SECRET_KEY_BASE=your_secret_key_here
CORS_ORIGINS=http://localhost:3000,http://localhost:3001
```

### 3. API Testing

The API will be available at: `http://localhost:3000/api/v1`

Test the health endpoint:
```bash
curl http://localhost:3000/health
```

## 🔐 Authentication

### Login
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@milkdelivery.com", "password": "password123"}'
```

### Use Token
```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  http://localhost:3000/api/v1/dashboard
```

## 📊 Main API Endpoints

### Authentication
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/register` - User registration
- `DELETE /api/v1/auth/logout` - User logout

### Core Resources
- `GET /api/v1/dashboard` - Dashboard data
- `GET /api/v1/customers` - Customer management
- `GET /api/v1/products` - Product catalog
- `GET /api/v1/delivery_assignments` - Delivery tracking
- `GET /api/v1/invoices` - Invoice system

### Analytics
- `GET /api/v1/analytics/dashboard` - Analytics overview
- `GET /api/v1/analytics/revenue_analytics` - Revenue reports
- `GET /api/v1/analytics/delivery_performance` - Delivery metrics

## 📁 Project Structure

```
app/
├── controllers/
│   ├── api/v1/
│   │   ├── authentication_controller.rb
│   │   ├── customers_controller.rb
│   │   ├── products_controller.rb
│   │   ├── delivery_assignments_controller.rb
│   │   └── ...
│   └── application_controller.rb
├── models/
│   ├── customer.rb
│   ├── product.rb
│   ├── delivery_assignment.rb
│   ├── invoice.rb
│   └── user.rb
└── controllers/concerns/
    └── json_web_token.rb

config/
├── routes.rb
├── application.rb
└── database.yml

db/
├── migrate/
└── schema.rb
```

## 🗄️ Database Schema

### Key Models
- **Users** - Admin and delivery personnel
- **Customers** - Customer information with location
- **Products** - Product catalog with inventory
- **DeliveryAssignments** - Delivery scheduling
- **Invoices** - Billing and payments
- **DeliverySchedules** - Recurring deliveries

## 🔧 Configuration

### CORS Setup
The API is configured to accept requests from frontend applications:

```ruby
# config/application.rb
config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
```

### JWT Configuration
JWT tokens are configured in `app/controllers/concerns/json_web_token.rb`

## 🧪 Testing

```bash
# Run tests
rails test

# Run with coverage
rails test --verbose
```

## 🚀 Deployment

### Heroku
```bash
# Create Heroku app
heroku create milk-delivery-api

# Add PostgreSQL
heroku addons:create heroku-postgresql:mini

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate
```

### Docker
```bash
# Build image
docker build -t milk-delivery-api .

# Run container
docker run -p 3000:3000 milk-delivery-api
```

## 📝 API Documentation

For complete API documentation with examples, see: [API_DOCUMENTATION.md](API_DOCUMENTATION.md)

## 🔍 Troubleshooting

### Common Issues

**Database Connection**
```bash
rails db:reset
rails db:migrate
```

**CORS Issues**
- Check `config/application.rb` CORS settings
- Verify frontend URL in CORS origins

**JWT Issues**
- Ensure `SECRET_KEY_BASE` is set
- Check token expiration (24 hours default)

## 📄 License

MIT License - see LICENSE file for details

## 💬 Support

- Email: support@milkdelivery.com
- Issues: Create GitHub issues for bugs/features

---

**Backend Repository** | Built with Ruby on Rails ❤️