# config/routes.rb
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
  resources :customers
  
  # Delivery People Management
  # resources :delivery_people, path: 'delivery-person' do
  #   member do
  #     get :assign_customers
  #     patch :update_assignments
  #     delete :unassign_customer
  #   end
    
  #   collection do
  #     post :bulk_assign
  #     get :statistics
  #   end
  # end
  
  resources :delivery_people, path: 'delivery-person' do
  member do
    get :assign_customers
    patch :update_assignments
    get :manage_customers        # New route for managing assigned customers
    patch :update_customer_assignments  # New route for updating customer assignments
    delete :unassign_customer
  end
  
  collection do
    post :bulk_assign
    get :statistics
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
  
  # Delivery Assignments
  resources :delivery_assignments, path: 'assign_deliveries' do
    member do
      patch :complete
      patch :cancel
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
    end
  end

end