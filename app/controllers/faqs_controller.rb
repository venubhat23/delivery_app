class FaqsController < ApplicationController
  before_action :set_faq, only: [:show, :edit, :update, :destroy, :activate, :deactivate]
  before_action :authenticate_user!

  def index
    @faqs = Faq.includes(:customer).order(:sort_order, :created_at)
    @faqs = @faqs.for_locale(params[:locale]) if params[:locale].present?
    @faqs = @faqs.by_category(params[:category]) if params[:category].present?
    @faqs = @faqs.page(params[:page])
  end

  def show
  end

  def new
    @faq = Faq.new
  end

  def edit
  end

  def create
    @faq = Faq.new(faq_params)

    if @faq.save
      redirect_to faqs_path, notice: 'FAQ was successfully created.'
    else
      render :new
    end
  end

  def update
    if @faq.update(faq_params)
      redirect_to faqs_path, notice: 'FAQ was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @faq.destroy
    redirect_to faqs_path, notice: 'FAQ was successfully deleted.'
  end

  def activate
    @faq.activate!
    redirect_to faqs_path, notice: 'FAQ was activated.'
  end

  def deactivate
    @faq.deactivate!
    redirect_to faqs_path, notice: 'FAQ was deactivated.'
  end

  def move_up
    @faq = Faq.find(params[:id])
    @faq.move_up!
    redirect_to faqs_path
  end

  def move_down
    @faq = Faq.find(params[:id])
    @faq.move_down!
    redirect_to faqs_path
  end

  def reorder
    if params[:faq_ids].present?
      Faq.reorder_within_category!(params[:category], params[:locale], params[:faq_ids])
      render json: { success: true }
    else
      render json: { error: 'No FAQ IDs provided' }, status: :bad_request
    end
  end

  private

  def set_faq
    @faq = Faq.find(params[:id])
  end

  def faq_params
    params.require(:faq).permit(:question, :answer, :category, :locale, :sort_order, :is_active)
  end
end