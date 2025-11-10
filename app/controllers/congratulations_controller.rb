class CongratulationsController < ApplicationController
  skip_before_action :require_login, only: [:show]

  def show
    render layout: false
  end
end