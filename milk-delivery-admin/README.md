# Milk Delivery Admin Panel

A modern, responsive admin panel built with React, TypeScript, and Material-UI for managing a milk delivery business.

## 🚀 Features

- **Authentication & Authorization** - Secure login with JWT tokens
- **Modern UI/UX** - Beautiful interface built with Material-UI
- **Responsive Design** - Works seamlessly on desktop, tablet, and mobile
- **Customer Management** - Add, edit, and manage customers with location tracking
- **Product Management** - Handle inventory and product catalog
- **Delivery Management** - Assign deliveries and track delivery personnel
- **Invoice Generation** - Create and manage invoices automatically
- **Analytics & Reports** - Comprehensive dashboard with charts and metrics
- **Real-time Updates** - Live data updates using React Query

## 🛠️ Technologies Used

- **React 19** - Latest version with hooks
- **TypeScript** - Type-safe development
- **Material-UI (MUI)** - Modern component library
- **React Router** - Client-side routing
- **React Query** - Server state management
- **Axios** - HTTP client for API calls
- **Recharts** - Beautiful charts and graphs
- **Date-fns** - Date manipulation library

## 📋 Prerequisites

Before running this application, make sure you have:

- Node.js (v16 or higher)
- npm or yarn
- Rails API backend running on `http://localhost:3000`

## 🚀 Getting Started

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd milk-delivery-admin
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   Create a `.env` file in the root directory:
   ```env
   REACT_APP_API_URL=http://localhost:3000/api/v1
   REACT_APP_APP_NAME=Milk Delivery Admin
   REACT_APP_VERSION=1.0.0
   ```

4. **Start the development server**
   ```bash
   npm start
   ```

5. **Open your browser**
   Navigate to `http://localhost:3000` to view the application.

### Building for Production

```bash
npm run build
```

This builds the app for production to the `build` folder.

## 🔐 Authentication

The application uses JWT-based authentication. Use these demo credentials to log in:

- **Email:** admin@milkdelivery.com
- **Password:** password123

## 📱 Application Structure

```
src/
├── components/          # Reusable UI components
│   ├── Layout/         # Main layout with sidebar
│   └── ProtectedRoute/ # Authentication guard
├── contexts/           # React contexts
│   └── AuthContext.tsx # Authentication state management
├── pages/              # Page components
│   ├── Dashboard/      # Main dashboard
│   ├── Customers/      # Customer management
│   ├── Products/       # Product management
│   ├── DeliveryAssignments/ # Delivery assignments
│   ├── DeliverySchedules/   # Delivery schedules
│   ├── Invoices/       # Invoice management
│   ├── Users/          # User management
│   ├── Analytics/      # Analytics and reports
│   └── Login/          # Login page
├── hooks/              # Custom React hooks
├── services/           # API service functions
├── types/              # TypeScript type definitions
├── utils/              # Utility functions
└── App.tsx             # Main application component
```

## 🎨 UI/UX Features

### Modern Design
- Clean, professional interface with gradient accents
- Consistent spacing and typography
- Intuitive navigation with visual feedback

### Responsive Layout
- Mobile-first design approach
- Collapsible sidebar on smaller screens
- Touch-friendly interface elements

### Interactive Elements
- Loading states and animations
- Toast notifications for user feedback
- Confirmation dialogs for destructive actions

### Data Visualization
- Interactive charts and graphs
- Real-time metrics and KPIs
- Export capabilities for reports

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REACT_APP_API_URL` | Backend API base URL | `http://localhost:3000/api/v1` |
| `REACT_APP_APP_NAME` | Application name | `Milk Delivery Admin` |
| `REACT_APP_VERSION` | Application version | `1.0.0` |

### API Integration

The application connects to a Rails API backend. Make sure the following endpoints are available:

- `POST /auth/login` - User authentication
- `GET /dashboard` - Dashboard data
- `GET /customers` - Customer list
- `GET /products` - Product list
- `GET /delivery_assignments` - Delivery assignments
- `GET /invoices` - Invoice list

## 📊 Key Features

### Dashboard
- Real-time statistics and metrics
- Recent activity feed
- Quick action buttons
- Revenue and delivery charts

### Customer Management
- Customer profiles with contact information
- Location tracking with Google Maps integration
- Delivery history and preferences
- Bulk import/export functionality

### Delivery Management
- Assign deliveries to personnel
- Track delivery status in real-time
- Route optimization suggestions
- Performance analytics

### Invoice System
- Automated invoice generation
- Multiple payment status tracking
- PDF export functionality
- Payment history and reminders

## 🚀 Deployment

### Using Netlify
1. Build the project: `npm run build`
2. Deploy the `build` folder to Netlify
3. Set environment variables in Netlify dashboard

### Using Vercel
1. Connect your repository to Vercel
2. Set environment variables in Vercel dashboard
3. Deploy automatically on push

### Using Docker
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

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 API Documentation

For detailed API documentation, see [API_DOCUMENTATION.md](../API_DOCUMENTATION.md)

## 🔍 Troubleshooting

### Common Issues

**CORS Errors**
- Ensure the Rails backend has CORS configured properly
- Check that `REACT_APP_API_URL` points to the correct backend URL

**Authentication Issues**
- Verify JWT token is being sent in Authorization header
- Check token expiration and refresh logic

**Build Errors**
- Clear node_modules and reinstall: `rm -rf node_modules && npm install`
- Check for TypeScript errors: `npm run type-check`

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 💬 Support

For support and questions:
- Email: support@milkdelivery.com
- Documentation: [docs.milkdelivery.com](https://docs.milkdelivery.com)
- Issues: [GitHub Issues](https://github.com/milkdelivery/admin/issues)

---

Built with ❤️ for efficient milk delivery management.
