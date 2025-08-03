class Api::DeliveryPeopleController < ApplicationController
  before_action :require_login

  def search
    @delivery_people = User.delivery_people
                          .where("name ILIKE ?", "%#{params[:q]}%")
                          .limit(20)
                          .order(:name)

    render json: {
      results: @delivery_people.map do |person|
        {
          id: person.id,
          text: "#{person.name} - #{person.phone}",
          name: person.name,
          phone: person.phone,
          email: person.email
        }
      end
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