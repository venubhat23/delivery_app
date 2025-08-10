class Api::CustomersController < Api::BaseController
  def search
    search_term = params[:q].to_s.strip
    page = params[:page]&.to_i || 1
    
    # Basic paginated JSON for Select2 or similar
    scope = Customer.active.order(:name)
    if search_term.present?
      like = "%#{search_term}%"
      scope = scope.where(
        "name ILIKE :q OR phone_number ILIKE :q OR alt_phone_number ILIKE :q OR email ILIKE :q OR member_id ILIKE :q",
        q: like
      )
    end

    customers = scope.page(page).per(20)

    render json: {
      results: customers.map { |customer|
        {
          id: customer.id,
          text: [customer.name, customer.phone_number.presence || customer.alt_phone_number, (customer.member_id.present? ? "ID: #{customer.member_id}" : nil)].compact.join(" · "),
          name: customer.name,
          phone: customer.phone_number.presence || customer.alt_phone_number,
          member_id: customer.member_id
        }
      },
      pagination: { more: customers.next_page.present? }
    }
  end

  def index
    page = params[:page].presence || 1
    per_page = 20
    
    customers = Customer.order(:name)
    
    if params[:q].present?
      like = "%#{params[:q]}%"
      customers = customers.where(
        "name ILIKE :q OR phone_number ILIKE :q OR alt_phone_number ILIKE :q",
        q: like
      )
    end
    
    customers = customers.page(page).per(per_page)
    
    render json: {
      results: customers.map do |customer|
        {
          id: customer.id,
          text: "#{customer.name} - #{customer.phone_number.presence || customer.alt_phone_number}",
          name: customer.name,
          phone: customer.phone_number.presence || customer.alt_phone_number,
          address: customer.address
        }
      end,
      pagination: {
        more: customers.next_page.present?
      }
    }
  end
end