class CmsPagesController < ApplicationController
  before_action :set_cms_page, only: [:show, :edit, :update, :destroy, :publish, :unpublish]
  before_action :authenticate_user!

  def index
    @cms_pages = CmsPage.includes(:customer).recent
    @cms_pages = @cms_pages.for_locale(params[:locale]) if params[:locale].present?
    @cms_pages = @cms_pages.for_slug(params[:slug]) if params[:slug].present?
    @cms_pages = @cms_pages.page(params[:page])
  end

  def show
  end

  def new
    @cms_page = CmsPage.new
  end

  def edit
  end

  def create
    @cms_page = CmsPage.new(cms_page_params)

    if @cms_page.save
      redirect_to cms_pages_path, notice: 'Page was successfully created.'
    else
      render :new
    end
  end

  def update
    if @cms_page.update(cms_page_params)
      redirect_to cms_pages_path, notice: 'Page was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @cms_page.destroy
    redirect_to cms_pages_path, notice: 'Page was successfully deleted.'
  end

  def publish
    @cms_page.publish!
    redirect_to cms_pages_path, notice: 'Page was published.'
  end

  def unpublish
    @cms_page.unpublish!
    redirect_to cms_pages_path, notice: 'Page was unpublished.'
  end

  def schedule_publish
    @cms_page = CmsPage.find(params[:id])
    if params[:publish_at].present?
      @cms_page.schedule_publish!(params[:publish_at])
      redirect_to cms_pages_path, notice: 'Page was scheduled for publishing.'
    else
      redirect_to cms_pages_path, alert: 'Please provide a valid publish date.'
    end
  end

  private

  def set_cms_page
    @cms_page = CmsPage.find(params[:id])
  end

  def cms_page_params
    params.require(:cms_page).permit(:slug, :version, :title, :content, :locale, :published_at)
  end
end