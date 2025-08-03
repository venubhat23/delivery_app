class Api::CustomersController < ApplicationController
  before_action :require_login

  def search
    @customers = Customer.where("name ILIKE ?", "%#{params[:q]}%")
                        .limit(20)
                        .order(:name)

    render json: {
      results: @customers.map do |customer|
        {
          id: customer.id,
          text: "#{customer.name} - #{customer.phone}",
          name: customer.name,
          phone: customer.phone,
          address: customer.address
        }
      end
    }
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