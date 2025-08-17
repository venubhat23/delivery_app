class Api::DeliveryPeopleController < ApplicationController
  before_action :require_login

  def search
    search_term = params[:q].to_s.strip
    page = params[:page]&.to_i || 1
    
    @delivery_people = User.delivery_people.order(:name)
    if search_term.present?
      @delivery_people = @delivery_people.where("name ILIKE ? OR phone ILIKE ? OR email ILIKE ?", 
                                               "%#{search_term}%", "%#{search_term}%", "%#{search_term}%")
    end
    
    begin
      delivery_people = @delivery_people.page(page).per(20)
    rescue
      delivery_people = @delivery_people.limit(20)
    end

    render json: {
      results: delivery_people.map do |person|
        {
          id: person.id,
          text: [person.name, person.phone.presence, person.email.presence].compact.join(" · "),
          data: {
            name: person.name,
            phone: person.phone,
            email: person.email
          }
        }
      end,
      pagination: { more: delivery_people.next_page.present? }
    }
  end

  def index
    page = params[:page] || 1
    per_page = 20
    
    @delivery_people = User.delivery_people
    
    if params[:q].present?
      @delivery_people = @delivery_people.where("name ILIKE ? OR phone ILIKE ?", 
                                               "%#{params[:q]}%", "%#{params[:q]}%")
    end
    
    @delivery_people = @delivery_people.page(page).per(per_page).order(:name)
    
    render json: {
      results: @delivery_people.map do |person|
        {
          id: person.id,
          text: "#{person.name} - #{person.phone}",
          name: person.name,
          phone: person.phone,
          email: person.email
        }
      end,
      pagination: {
        more: @delivery_people.next_page.present?
      }
    }
  end
end