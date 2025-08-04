class Api::SalesCustomersController < Api::BaseController
  def search
    search_term = params[:q]
    page = params[:page]&.to_i || 1
    
    options = {
      search_fields: [:name, :phone_number, :email],
      display_method: ->(customer) { "#{customer.name} - #{customer.phone_number}" },
      scope: :active,
      per_page: 20
    }
    
    results = if page > 1
      paginated_search_results(SalesCustomer, search_term, page, options)
    else
      {
        results: search_results(SalesCustomer, search_term, options),
        pagination: { more: false }
      }
    end
    
    render json: results
  end
end