class Api::ProductsController < ApplicationController
  before_action :require_login

  def search
    @products = Product.where("name ILIKE ?", "%#{params[:q]}%")
                      .limit(20)
                      .order(:name)

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
      end
    }
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