class CategoriesController < ApplicationController
  before_action :require_login
  before_action :set_category, only: [:show, :edit, :update, :destroy, :add_products, :assign_products]

  def index
    @categories = Category.all.order(:name)
    @total_categories = @categories.count
  end

  def show
    @products = @category.products.order(:name)
    @uncategorized_products = Product.where(category_id: nil).order(:name)
    @available_products = Product.where.not(category_id: @category.id).or(Product.where(category_id: nil)).order(:name)
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)
    
    if @category.save
      redirect_to @category, notice: 'Category was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to @category, notice: 'Category was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to categories_url, notice: 'Category was successfully deleted.'
  end

  def add_products
    @available_products = Product.where.not(category_id: @category.id).or(Product.where(category_id: nil)).order(:name)
  end

  def assign_products
    if params[:product_ids].present?
      products = Product.where(id: params[:product_ids])
      products.update_all(category_id: @category.id)
      
      redirect_to @category, notice: "#{products.count} product(s) successfully assigned to #{@category.name}."
    else
      redirect_to @category, alert: 'Please select at least one product to assign.'
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description, :color)
  end
end