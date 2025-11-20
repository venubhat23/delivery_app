class Affiliate::ProductsController < ApplicationController
  layout 'affiliate'
  skip_before_action :require_login
  before_action :authenticate_affiliate!

  def index
    @products = Product.where(is_active: true).includes(:category).order(:name)

    # Filter by category if provided
    if params[:category_id].present?
      @products = @products.where(category_id: params[:category_id])
    end

    # Search functionality
    if params[:search].present?
      @products = @products.where("name ILIKE ?", "%#{params[:search]}%")
    end

    @categories = Category.joins(:products).where(products: { is_active: true }).distinct.order(:name)
    @cart_items = session[:affiliate_cart] || []
    @cart_count = @cart_items.sum { |item| item['quantity'].to_i }
  end

  def show
    @product = Product.find(params[:id])
    @cart_items = session[:affiliate_cart] || []
    @cart_count = @cart_items.sum { |item| item['quantity'].to_i }
  end

  private

  def authenticate_affiliate!
    unless current_affiliate
      redirect_to affiliate_login_path, alert: 'Please log in to access products.'
    end
  end
end