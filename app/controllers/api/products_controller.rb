class Api::ProductsController < Api::BaseController
  def search
    search_term = params[:q]
    page = params[:page]&.to_i || 1
    
    options = {
      search_fields: [:name, :description],
      display_method: ->(product) { "#{product.name} - Rs#{product.price}" },
      scope: :active,
      per_page: 20
    }
    
    results = if page > 1
      paginated_search_results(Product, search_term, page, options)
    else
      {
        results: search_results(Product, search_term, options),
        pagination: { more: false }
      }
    end
    
    render json: results
  end

  def index
    page = params[:page] || 1
    per_page = 20
    
    @products = Product.includes(:category)
    
    if params[:q].present?
      @products = @products.where("name ILIKE ? OR description ILIKE ?", 
                                 "%#{params[:q]}%", "%#{params[:q]}%")
    end

    if params[:category_id].present?
      @products = @products.where(category_id: params[:category_id])
    end
    
    @products = @products.page(page).per(per_page).order(:name)
    
    render json: {
      results: @products.map do |product|
        {
          id: product.id,
          text: "#{product.name} - Rs#{product.price}",
          name: product.name,
          price: product.price,
          unit_type: product.unit_type,
          category: product.category&.name
        }
      end,
      pagination: {
        more: @products.next_page.present?
      }
    }
  end
end