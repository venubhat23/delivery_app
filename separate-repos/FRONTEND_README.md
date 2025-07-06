# Milk Delivery Admin Frontend

A modern, responsive admin panel built with React, TypeScript, and Material-UI for managing milk delivery operations.

## 🚀 Features

- **Modern React 19** - Latest React with hooks and TypeScript
- **Material-UI Design** - Professional, responsive interface
- **JWT Authentication** - Secure login with token management
- **Real-time Data** - Live updates with React Query
- **Mobile Responsive** - Works on all device sizes
- **Beautiful Charts** - Interactive analytics and reports
- **Dark/Light Theme** - Modern gradient design

## 🛠️ Technology Stack

- **React 19** - Frontend framework
- **TypeScript** - Type-safe development
- **Material-UI (MUI)** - Component library
- **React Router** - Client-side routing
- **React Query** - Server state management
- **Axios** - HTTP client
- **Recharts** - Data visualization
- **Date-fns** - Date utilities

## 📋 Prerequisites

- Node.js 16 or higher
- npm or yarn
- Rails API backend running

## 🚀 Quick Start

### 1. Extract and Setup

```bash
# Extract the frontend files
tar -xzf milk-delivery-frontend.tar.gz
cd milk-delivery-frontend

# Install dependencies
npm install
```

### 2. Environment Configuration

Create a `.env` file:

```env
REACT_APP_API_URL=http://localhost:3000/api/v1
REACT_APP_APP_NAME=Milk Delivery Admin
REACT_APP_VERSION=1.0.0
```

### 3. Start Development Server

```bash
npm start
```

The app will open at `http://localhost:3000`

## 🔐 Login Credentials

Use these demo credentials:

- **Email:** admin@milkdelivery.com
- **Password:** password123

## 📱 Application Features

### 🏠 Dashboard
- Real-time statistics and KPIs
- Recent activity feed
- Revenue and delivery charts
- Quick action shortcuts

### 👥 Customer Management
- Customer profiles with contact info
- Location tracking with coordinates
- Delivery history and preferences
- Bulk import/export via CSV
- Search and filter capabilities

### 📦 Product Management
- Product catalog with inventory
- Stock level monitoring
- Low stock alerts
- Product performance metrics

### 🚚 Delivery Management
- Delivery assignment tracking
- Real-time status updates
- Delivery person performance
- Route optimization suggestions

### 🧾 Invoice System
- Automated invoice generation
- Payment status tracking
- PDF export functionality
- Revenue analytics

### 📊 Analytics & Reports
- Comprehensive dashboards
- Interactive charts and graphs
- Performance metrics
- Export capabilities

## 🎨 UI/UX Design

### Modern Interface
- Clean, professional design
- Gradient color scheme
- Consistent spacing and typography
- Intuitive navigation

### Responsive Layout
- Mobile-first approach
- Collapsible sidebar navigation
- Touch-friendly interface
- Adaptive components

### Interactive Elements
- Loading states and animations
- Toast notifications
- Confirmation dialogs
- Smooth transitions

## 📁 Project Structure

```
src/
├── components/
│   ├── Layout/
│   │   └── Layout.tsx          # Main layout with sidebar
│   └── ProtectedRoute/
│       └── ProtectedRoute.tsx  # Auth guard component
├── contexts/
│   └── AuthContext.tsx         # Authentication state
├── pages/
│   ├── Dashboard/
│   │   └── Dashboard.tsx       # Main dashboard
│   ├── Customers/
│   │   └── Customers.tsx       # Customer management
│   ├── Products/
│   │   └── Products.tsx        # Product catalog
│   ├── DeliveryAssignments/
│   │   └── DeliveryAssignments.tsx
│   ├── Invoices/
│   │   └── Invoices.tsx        # Invoice management
│   ├── Users/
│   │   └── Users.tsx           # User management
│   ├── Analytics/
│   │   └── Analytics.tsx       # Reports and analytics
│   └── Login/
│       └── Login.tsx           # Login page
├── hooks/                      # Custom React hooks
├── services/                   # API service functions
├── types/                      # TypeScript definitions
├── utils/                      # Utility functions
└── App.tsx                     # Main app component
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REACT_APP_API_URL` | Backend API URL | `http://localhost:3000/api/v1` |
| `REACT_APP_APP_NAME` | Application name | `Milk Delivery Admin` |
| `REACT_APP_VERSION` | App version | `1.0.0` |

### API Integration

The frontend connects to these backend endpoints:

- `POST /auth/login` - Authentication
- `GET /dashboard` - Dashboard data
- `GET /customers` - Customer list
- `GET /products` - Product catalog
- `GET /delivery_assignments` - Deliveries
- `GET /invoices` - Invoice data
- `GET /analytics/*` - Analytics data

## 🚀 Build and Deploy

### Development Build
```bash
npm start
```

### Production Build
```bash
npm run build
```

### Testing
```bash
npm test
```

### Type Checking
```bash
npm run type-check
```

## 🌐 Deployment Options

### Netlify
1. Build: `npm run build`
2. Deploy `build/` folder
3. Set environment variables

### Vercel
1. Connect GitHub repository
2. Auto-deploy on push
3. Configure environment variables

### Docker
```dockerfile
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npx", "serve", "-s", "build"]
```

## 🎯 Key Components

### Authentication System
- JWT token management
- Automatic token refresh
- Secure route protection
- Login/logout functionality

### Data Management
- React Query for server state
- Real-time data updates
- Optimistic updates
- Error handling

### UI Components
- Custom Material-UI theme
- Reusable components
- Consistent styling
- Responsive design

## 🔍 Troubleshooting

### Common Issues

**API Connection Issues**
- Verify `REACT_APP_API_URL` in `.env`
- Check backend server is running
- Ensure CORS is configured on backend

**Authentication Problems**
- Clear browser localStorage
- Check JWT token expiration
- Verify credentials with backend

**Build Errors**
```bash
# Clear cache and reinstall
rm -rf node_modules package-lock.json
npm install

# Check for TypeScript errors
npm run type-check
```

## 📊 Performance

- Code splitting with React.lazy()
- Optimized bundle size
- Image optimization
- Caching strategies

## 🧪 Testing

```bash
# Run tests
npm test

# Run tests with coverage
npm run test:coverage

# E2E tests (if configured)
npm run test:e2e
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -m 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Create Pull Request

## 📄 License

MIT License - see LICENSE file for details

## 💬 Support

- Email: support@milkdelivery.com
- Documentation: [docs.milkdelivery.com](https://docs.milkdelivery.com)
- Issues: Create GitHub issues

---

**Frontend Repository** | Built with React & TypeScript ⚛️