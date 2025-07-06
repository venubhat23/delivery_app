Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Authentication routes
      post 'auth/login', to: 'authentication#login'
      post 'auth/register', to: 'authentication#register'
      delete 'auth/logout', to: 'authentication#logout'
      
      # Dashboard
      get 'dashboard', to: 'dashboard#index'
      
      # Users management
      resources :users, only: [:index, :show, :create, :update, :destroy]
      
      # Customer management
      resources :customers do
        collection do
          post :bulk_import
          post :validate_csv
          get :export_csv
        end
        member do
          patch :assign_delivery_person
          get :delivery_history
        end
      end
      
      # Product management
      resources :products do
        collection do
          get :low_stock
        end
      end
      
      # Delivery People Management
      resources :delivery_people, controller: 'users', constraints: { role: 'delivery_person' } do
        member do
          get :assigned_customers
          patch :assign_customers
          get :delivery_statistics
        end
      end
      
      # Delivery Assignments
      resources :delivery_assignments do
        collection do
          get :by_delivery_person
          get :by_date
          post :bulk_create
        end
        member do
          patch :update_status
          patch :complete
          patch :cancel
        end
      end
      
      # Delivery Schedules
      resources :delivery_schedules do
        member do
          patch :activate
          patch :deactivate
          get :assignments
        end
      end
      
      # Invoices
      resources :invoices do
        collection do
          get :generate_monthly
          post :generate_for_customer
          get :analytics
        end
        member do
          patch :mark_as_paid
          get :download_pdf
        end
      end
      
      # Purchase Management
      resources :purchase_products
      resources :purchase_invoices do
        member do
          patch :mark_as_paid
          get :download_pdf
        end
      end
      
      # Sales Management
      resources :sales_products
      resources :sales_invoices do
        member do
          patch :mark_as_paid
          get :download_pdf
        end
      end
      
      # Analytics and Reports
      namespace :analytics do
        get :dashboard
        get :delivery_performance
        get :customer_analytics
        get :revenue_analytics
        get :product_analytics
      end
    end
  end
  
  # Health check
  get '/health', to: 'health#check'
end