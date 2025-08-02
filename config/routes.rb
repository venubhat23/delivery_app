Rails.application.routes.draw do
  root 'dashboard#index'
  
  # Authentication routes
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'
  
  get '/signup', to: 'users#new'
  post '/signup', to: 'users#create'
  
  # Main application routes with full CRUD
  resources :products do
    collection do
      get :assign_categories
      patch :update_categories
    end
  end
  resources :categories
  resources :customers do
    collection do
      get :bulk_import
      post :process_bulk_import
      post :validate_csv
      get :download_template
      get :enhanced_bulk_import
      post :process_enhanced_bulk_import
      post :validate_enhanced_csv
      get :download_enhanced_template
    end
  end
  
  resources :advertisements
  
  resources :parties do
    collection do
      get :bulk_import
      post :process_bulk_import
      post :validate_csv
      get :download_template
    end
  end
  
  # Purchase Products System
  resources :purchase_products do
    collection do
      get :search
    end
    member do
      patch :mark_as_paid
    end
  end
  
  # Sales Products System (NEW)
  resources :sales_products do
    collection do
      get :search
    end
  end
  
  # Purchase Invoices
  resources :purchase_invoices do
    member do
      patch :mark_as_paid
      get :mark_as_paid
      patch :add_payment
      get :download_pdf
    end
    
    collection do
      post :bulk_upload
    end
  end
  
  # Purchase Customers
  resources :purchase_customers do
    collection do
      get :search
    end
  end
  
  # Sales Invoices (NEW)
  resources :sales_invoices do
    member do
      patch :mark_as_paid
      get :mark_as_paid
      get :download_pdf
      get :get_product_details
      get :get_customer_details
    end
    
    collection do
      get :profit_analysis
      get :sales_analysis
      get 'products/:id/details', to: 'sales_invoices#get_product_details', as: 'product_details'
      get 'customers/:id/details', to: 'sales_invoices#get_customer_details', as: 'customer_details'
    end
  end
  
  # Sales Customers
  resources :sales_customers do
    collection do
      get :search
    end
  end
  
  # Delivery People Management
  resources :delivery_people, path: 'delivery-person' do
    member do
      get :assign_customers
      patch :update_assignments
      get :manage_customers
      patch :update_customer_assignments
      delete :unassign_customer
    end
    
    collection do
      post :bulk_assign
      get :statistics
    end
  end
  
  # Delivery Assignments (consolidated - removed duplicate)
  resources :delivery_assignments, path: 'assign_deliveries' do
    member do
      patch :complete
      patch :cancel
    end
    
    collection do
      get :bulk, path: 'bulk-automate'
      post :process_bulk_assignments, path: 'bulk-process', as: 'process_bulk_assignments'
      post :bulk_complete, path: 'bulk-complete'
    end
  end
  
  # Delivery Schedules
  resources :delivery_schedules, path: 'schedules' do
    member do
      patch :generate_assignments
      patch :cancel_schedule
    end
    
    collection do
      post :create_bulk
    end
  end
  
  # Schedule Management
  resources :schedule_management, path: 'manage-schedules', only: [:index] do
    collection do
      post :replicate_schedules
      get :month_summary
    end
  end
  
  # Deliveries (for delivery person records)
  resources :deliveries do
    member do
      patch :update_status
    end
  end
  
  # Invoices with comprehensive functionality
  resources :invoices do
    member do
      patch :mark_as_paid
      post :share_whatsapp
    end
    
    collection do
      get :generate
      post :generate
      get :monthly_preview
      get :generate_monthly_for_all
      post :generate_monthly_for_all
    end
  end
  
  # Public invoice view (no authentication required)
  get '/invoice/:token', to: 'invoices#public_view', as: 'public_invoice'
  get '/invoice/:token/download', to: 'invoices#public_download_pdf', as: 'public_invoice_download', defaults: { format: :pdf }
  
  # Admin Settings
  resources :admin_settings, path: 'admin-settings'
  
  # Reports
  resources :reports, only: [:index] do
    collection do
      post :generate_gst_report
    end
    member do
      get :download_pdf
    end
  end
  
  # File Upload API
  post '/api/upload', to: 'uploads#create'
  
  # API routes
  namespace :api do
    namespace :v1 do
      post '/login', to: 'authentication#login'
      post '/signup', to: 'authentication#signup'
      post '/customer_signup', to: 'authentication#customer_signup'
      post '/customer_login', to: 'authentication#customer_login'
      post '/regenerate_token', to: 'authentication#regenerate_token'
    end
  end
end