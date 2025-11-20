class Franchise::DashboardController < Franchise::BaseController
  def index
    @total_bookings = current_franchise.total_bookings
    @total_amount = current_franchise.total_bookings_amount
    @pending_bookings = current_franchise.pending_bookings.count
    @completed_bookings = current_franchise.completed_bookings.count

    @recent_bookings = current_franchise.franchise_bookings
                                      .includes(:product)
                                      .order(created_at: :desc)
                                      .limit(5)

    @products = Product.all.order(:name)
  end
end