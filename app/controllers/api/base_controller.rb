class Api::BaseController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :require_login
  
  private
  
  def search_results(model_class, search_term, options = {})
    return [] if search_term.blank?
    
    # Default options
    limit = options[:limit] || 20
    search_fields = options[:search_fields] || [:name]
    display_method = options[:display_method] || :name
    scope = options[:scope]
    
    # Start with base query
    query = model_class.all
    query = query.send(scope) if scope && query.respond_to?(scope)
    
    # Build search conditions
    search_conditions = search_fields.map do |field|
      "#{field} ILIKE ?"
    end.join(' OR ')
    
    search_params = Array.new(search_fields.length, "%#{search_term}%")
    
    # Execute search
    results = query.where(search_conditions, *search_params)
                   .limit(limit)
                   .order(search_fields.first)
    
    # Format results for Select2
    results.map do |record|
      {
        id: record.id,
        text: record.send(display_method),
        data: record.as_json(only: [:id] + search_fields)
      }
    end
  end
  
  def paginated_search_results(model_class, search_term, page = 1, options = {})
    return { results: [], pagination: { more: false } } if search_term.blank?
    
    per_page = options[:per_page] || 20
    results = search_results(model_class, search_term, options.merge(limit: per_page + 1))
    
    has_more = results.length > per_page
    results = results.first(per_page) if has_more
    
    {
      results: results,
      pagination: {
        more: has_more
      }
    }
  end
end