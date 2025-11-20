class Affiliate::CartController < ApplicationController
  layout 'affiliate'
  skip_before_action :require_login
  before_action :authenticate_affiliate!

  def index
    @cart_items = get_cart_items_with_products
    @cart_total = calculate_cart_total
    @cart_count = @cart_items.sum { |item| item[:quantity] }
  end

  def add
    product = Product.find(params[:product_id])
    quantity = params[:quantity].to_f || 1
    price = params[:price].to_f || product.price

    cart = session[:affiliate_cart] || []

    # Check if product already in cart
    existing_item = cart.find { |item| item['product_id'] == product.id.to_s }

    if existing_item
      existing_item['quantity'] = (existing_item['quantity'].to_f + quantity).to_s
    else
      cart << {
        'product_id' => product.id.to_s,
        'quantity' => quantity.to_s,
        'price' => price.to_s
      }
    end

    session[:affiliate_cart] = cart

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          message: "#{product.name} added to cart",
          cart_count: cart.sum { |item| item['quantity'].to_f }
        }
      }
      format.html {
        redirect_to affiliate_products_path, notice: "#{product.name} added to cart"
      }
    end
  end

  def update
    cart = session[:affiliate_cart] || []
    item = cart.find { |item| item['product_id'] == params[:product_id] }

    if item
      if params[:quantity].to_f > 0
        item['quantity'] = params[:quantity]
      else
        cart.delete(item)
      end

      session[:affiliate_cart] = cart

      respond_to do |format|
        format.json {
          render json: {
            success: true,
            cart_total: calculate_cart_total,
            cart_count: cart.sum { |item| item['quantity'].to_f }
          }
        }
        format.html { redirect_to affiliate_cart_path }
      end
    else
      respond_to do |format|
        format.json { render json: { success: false, message: 'Item not found' } }
        format.html { redirect_to affiliate_cart_path, alert: 'Item not found' }
      end
    end
  end

  def remove
    cart = session[:affiliate_cart] || []
    cart.reject! { |item| item['product_id'] == params[:product_id] }
    session[:affiliate_cart] = cart

    respond_to do |format|
      format.json {
        render json: {
          success: true,
          message: 'Item removed from cart',
          cart_count: cart.sum { |item| item['quantity'].to_f }
        }
      }
      format.html {
        redirect_to affiliate_cart_path, notice: 'Item removed from cart'
      }
    end
  end

  def clear
    session[:affiliate_cart] = []

    respond_to do |format|
      format.json { render json: { success: true, message: 'Cart cleared' } }
      format.html { redirect_to affiliate_cart_path, notice: 'Cart cleared' }
    end
  end

  def checkout
    @cart_items = get_cart_items_with_products
    @cart_total = calculate_cart_total

    if @cart_items.empty?
      redirect_to affiliate_cart_path, alert: 'Your cart is empty'
      return
    end
  end

  def place_order
    @cart_items = get_cart_items_with_products

    if @cart_items.empty?
      redirect_to affiliate_cart_path, alert: 'Your cart is empty'
      return
    end

    begin
      ActiveRecord::Base.transaction do
        # Create bookings for each cart item
        @cart_items.each do |item|
          current_affiliate.affiliate_bookings.create!(
            product: item[:product],
            quantity: item[:quantity],
            price: item[:price],
            booking_date: Date.current,
            notes: params[:notes],
            status: 'pending'
          )
        end

        # Clear cart after successful order
        session[:affiliate_cart] = []

        redirect_to affiliate_bookings_path,
                   notice: "Order placed successfully! #{@cart_items.count} items have been booked."
      end
    rescue => e
      redirect_to affiliate_cart_path,
                 alert: "Failed to place order: #{e.message}"
    end
  end

  private

  def get_cart_items_with_products
    cart = session[:affiliate_cart] || []
    cart.map do |item|
      product = Product.find(item['product_id'])
      {
        product: product,
        quantity: item['quantity'].to_f,
        price: item['price'].to_f,
        total: item['quantity'].to_f * item['price'].to_f
      }
    rescue ActiveRecord::RecordNotFound
      nil
    end.compact
  end

  def calculate_cart_total
    get_cart_items_with_products.sum { |item| item[:total] }
  end

  def authenticate_affiliate!
    unless current_affiliate
      redirect_to affiliate_login_path, alert: 'Please log in to access cart.'
    end
  end
end