Rails.application.routes.draw do
  root 'dashboard#index'
  
  # Authentication routes
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'
  
  get '/signup', to: 'users#new'
  post '/signup', to: 'users#create'
  
  # Main application routes with full CRUD
  resources :products
  resources :categories do
    member do
      get :add_products
      patch :assign_products
    end
  end
  resources :customers do
    collection do
      get :bulk_import
      post :process_bulk_import
      post :validate_csv
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
      get :download_pdf
    end
    
    collection do
      get :profit_analysis
      get :sales_analysis
    end
  end
  
  # Sales Invoices (NEW)
  resources :sales_invoices do
    member do
      patch :mark_as_paid
      get :download_pdf
    end
    
    collection do
      get :profit_analysis
      get :sales_analysis
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
    end
    
    collection do
      get :generate
      post :generate
      get :monthly_preview
      get :generate_monthly_for_all
      post :generate_monthly_for_all
    end
  end
end