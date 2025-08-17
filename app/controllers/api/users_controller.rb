class Api::UsersController < Api::BaseController
  def search
    search_term = params[:q]
    page = params[:page]&.to_i || 1
    
    options = {
      search_fields: [:name, :email],
      display_method: :name,
      scope: :active,
      per_page: 20
    }
    
    results = if page > 1
      paginated_search_results(User, search_term, page, options)
    else
      {
        results: search_results(User, search_term, options),
        pagination: { more: false }
      }
    end
    
    render json: results
  end
  
  def search_delivery_people
    search_term = params[:q]
    page = params[:page]&.to_i || 1
    
    options = {
      search_fields: [:name, :email],
      display_method: :name,
      per_page: 20
    }
    
    # Filter for delivery people only
    query = User.where(role: 'delivery_person')
    
    results = if search_term.present?
      search_conditions = options[:search_fields].map do |field|
        "#{field} ILIKE ?"
      end.join(' OR ')
      
      search_params = Array.new(options[:search_fields].length, "%#{search_term}%")
      
      delivery_people = query.where(search_conditions, *search_params)
                            .limit(options[:per_page])
                            .order(:name)
      
      {
        results: delivery_people.map do |user|
          {
            id: user.id,
            text: [user.name, user.phone.presence, user.email.presence].compact.join(" · "),
            data: {
              name: user.name,
              phone: user.phone,
              email: user.email
            }
          }
        end,
        pagination: { more: false }
      }
    else
      # Return all delivery people when no search term
      all_delivery_people = query.limit(options[:per_page]).order(:name)
      {
        results: all_delivery_people.map do |user|
          {
            id: user.id,
            text: [user.name, user.phone.presence, user.email.presence].compact.join(" · "),
            data: {
              name: user.name,
              phone: user.phone,
              email: user.email
            }
          }
        end,
        pagination: { more: false }
      }
    end
    
    render json: results
  end
end