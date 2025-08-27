Rails.application.routes.draw do
  root 'dashboard#index'
  
  # Dashboard analytics endpoint
  get '/dashboard/delivery_analytics', to: 'dashboard#delivery_analytics'
  
  # Authentication routes
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'
  
  get '/signup', to: 'users#new'
  post '/signup', to: 'users#create'

  # API routes for searchable dropdowns
  namespace :api do
    get 'customers/search', to: 'customers#search'
    get 'sales_customers/search', to: 'sales_customers#search'
    get 'products/search', to: 'products#search'
    get 'sales_products/search', to: 'sales_products#search'
    get 'users/search', to: 'users#search'
    get 'delivery_people/search', to: 'users#search_delivery_people'
    get 'categories/search', to: 'categories#search'
    get 'parties/search', to: 'parties#search'
    
    # Settings API routes
    namespace :v1 do
      resources :settings, only: [:index] do
        collection do
          # FAQ endpoints
          get :faq
          post 'faq/ask', to: 'settings#ask_question'
          
          # CMS endpoints
          get 'cms/terms-of-service', to: 'settings#terms'
          get 'cms/privacy-policy', to: 'settings#privacy'
          
          # Contact/Support endpoints
          post :contact
          
          # Preferences endpoints
          get :referral
          get 'delivery-preferences', to: 'settings#delivery_preferences'
          put 'preferences', to: 'settings#update_preferences'
          put 'language', to: 'settings#update_language'
          
          # Address endpoints
          get :addresses
          post :addresses, to: 'settings#create_address'
          put 'addresses/:id', to: 'settings#update_address'
          delete 'addresses/:id', to: 'settings#delete_address'
          post 'addresses/:id/set_default', to: 'settings#set_default_address'
        end
      end
    end
  end
  
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
    
    member do
      patch :reassign_delivery_person
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
      patch :unassign_customers
      get :manage_customers
      patch :update_customer_assignments
      delete :unassign_customer
    end
    
    collection do
      post :bulk_assign
      get :statistics
    end
  end
  
  # JSON API for delivery people (for dropdowns)
  get '/delivery_people', to: 'delivery_people#index', defaults: { format: :json }
  
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
  
  # Schedules Management
  resources :schedules, only: [:index] do
    collection do
      post :create_schedule
      post :import_last_month
      post :import_selected_month
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
      patch :convert_to_completed
      post :share_whatsapp
    end
    
    collection do
      get :generate
      post :generate
      get :monthly_preview
      get :generate_monthly_for_all
      post :generate_monthly_for_all
      get :search_suggestions
    end
  end
  
  # Public invoice view (no authentication required)
  get '/invoice/:token', to: 'invoices#public_view', as: 'public_invoice'
  get '/invoice/:token/download', to: 'invoices#public_download_pdf', as: 'public_invoice_download', defaults: { format: :pdf }
  
  # Admin Settings
  resources :admin_settings, path: 'admin-settings' do
    collection do
      post :cleanup_tokens
      get :export_data
    end
  end
  
  # Reports
  resources :reports, only: [:index, :show] do
    collection do
      post :generate_gst_report
    end
    member do
      get :download_pdf
    end
  end
  
  # Milk Supply & Analytics routes
  resources :procurement_schedules, path: 'milk-procurement' do
    member do
      patch :generate_assignments
    end
    
    collection do
      get :analytics
    end
  end
  
  resources :procurement_assignments, path: 'milk-assignments' do
    member do
      patch :complete
      patch :cancel
    end
    
    collection do
      patch :bulk_update
      get :calendar
      get :daily_report
      get :analytics_data
    end
  end
  
  # Main Milk Analytics Dashboard
  resources :milk_analytics, path: 'milk-supply-analytics', only: [:index] do
    collection do
      get :calendar_view
      get :vendor_analysis
      get :profit_analysis
      get :inventory_analysis
      get :generate_reports
      get :saved_reports
      post :create_schedule
      patch :update_schedule
      delete :destroy_schedule
      get :get_schedule
    end
    
    member do
      get :show_report
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
  
  # Delivery Review
  get '/delivery-review', to: 'delivery_review#index'
  get '/delivery-review/data', to: 'delivery_review#data'
  post '/delivery-review/export', to: 'delivery_review#export'
  patch '/delivery-review/:id', to: 'delivery_review#update'
  delete '/delivery-review/:id', to: 'delivery_review#destroy'
  
  # Settings Management
  resources :faqs do
    member do
      patch :activate
      patch :deactivate
      patch :move_up
      patch :move_down
    end
    
    collection do
      patch :reorder
    end
  end
  
  resources :cms_pages, path: 'content-pages' do
    member do
      patch :publish
      patch :unpublish
      patch :schedule_publish
    end
  end
  
  resources :support_tickets, path: 'support' do
    member do
      patch :resolve
      patch :reopen
    end
  end
  
  resources :referral_codes, path: 'referrals', only: [:index, :show, :destroy] do
    collection do
      get :leaderboard
    end
  end
  
  # Customer preferences and addresses management
  resources :customer_preferences, path: 'customer-preferences' do
    collection do
      patch :bulk_update_notifications
    end
  end
  
  resources :customer_addresses, path: 'customer-addresses' do
    member do
      patch :set_default
    end
    
    collection do
      post :bulk_import
    end
  end
  
  # Nested customer addresses
  resources :customers do
    resources :customer_addresses, path: 'addresses', except: [:show]
  end
end