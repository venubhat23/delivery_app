class Api::CustomersController < Api::BaseController
  def search
    search_term = params[:q]
    page = params[:page]&.to_i || 1
    
    options = {
      search_fields: [:name, :phone_number, :email, :member_id],
      display_method: ->(customer) {
        parts = []
        parts << customer.name if customer.name.present?
        parts << customer.phone_number if customer.phone_number.present?
        parts << "ID: #{customer.member_id}" if customer.member_id.present?
        parts.join(" · ")
      },
      scope: :active,
      per_page: 20
    }
    
    results = if page > 1
      paginated_search_results(Customer, search_term, page, options)
    else
      {
        results: search_results(Customer, search_term, options),
        pagination: { more: false }
      }
    end
    
    render json: results
  end

  def index
    page = params[:page] || 1
    per_page = 20
    
    @customers = Customer.all
    
    if params[:q].present?
      @customers = @customers.where("name ILIKE ? OR phone ILIKE ?", 
                                   "%#{params[:q]}%", "%#{params[:q]}%")
    end
    
    @customers = @customers.page(page).per(per_page).order(:name)
    
    render json: {
      results: @customers.map do |customer|
        {
          id: customer.id,
          text: "#{customer.name} - #{customer.phone}",
          name: customer.name,
          phone: customer.phone,
          address: customer.address
        }
      end,
      pagination: {
        more: @customers.next_page.present?
      }
    }
  end
end