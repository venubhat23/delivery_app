class Affiliate::DashboardController < ApplicationController
  layout 'affiliate'
  skip_before_action :require_login
  before_action :authenticate_affiliate!

  def index
    @total_referrals = current_affiliate.total_referrals
    @approved_referrals = current_affiliate.approved_referrals
    @pending_referrals = current_affiliate.pending_referrals
    @total_earnings = current_affiliate.total_earnings
    @commission_rate = current_affiliate.commission_rate

    @recent_referrals = current_affiliate.referrals.recent.limit(5)
    @recent_bookings = current_affiliate.affiliate_bookings.recent.limit(5)

    @monthly_stats = {
      this_month_referrals: current_affiliate.referrals.this_month.count,
      last_month_referrals: current_affiliate.referrals.last_month.count,
      this_month_bookings: current_affiliate.affiliate_bookings.this_month.count,
      last_month_bookings: current_affiliate.affiliate_bookings.last_month.count
    }
  end

  private

  def authenticate_affiliate!
    unless current_affiliate
      redirect_to affiliate_login_path, alert: 'Please log in to access your dashboard.'
    end
  end

end