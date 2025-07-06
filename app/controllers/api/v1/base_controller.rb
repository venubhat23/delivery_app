class Api::V1::BaseController < ApplicationController
  private
  
  def pagination_params
    {
      page: params[:page] || 1,
      per_page: params[:per_page] || 25
    }
  end
  
  def search_params
    params.permit(:search, :sort_by, :sort_order, :filter_by, :filter_value)
  end
  
  def render_paginated(collection, serializer = nil)
    paginated = collection.page(pagination_params[:page]).per(pagination_params[:per_page])
    
    data = if serializer
      serializer.new(paginated, each_serializer: serializer)
    else
      paginated
    end
    
    render json: {
      data: data,
      pagination: {
        current_page: paginated.current_page,
        per_page: paginated.limit_value,
        total_pages: paginated.total_pages,
        total_count: paginated.total_count
      }
    }
  end
end