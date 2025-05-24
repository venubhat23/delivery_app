
# app/controllers/deliveries_controller.rb
class DeliveriesController < ApplicationController
  def index
    flash[:info] = "Delivery management coming soon!"
    redirect_to root_path
  end
end
