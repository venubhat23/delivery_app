class Admin::ReferralsController < ApplicationController
  before_action :require_login
  before_action :require_admin
  before_action :set_referral, only: [:show, :approve, :reject]

  def index
    @referrals = Referral.includes(:affiliate).order(created_at: :desc)
    @pending_referrals = @referrals.select { |r| r.status == 'pending' }
    @approved_referrals = @referrals.select { |r| r.status == 'approved' }
    @rejected_referrals = @referrals.select { |r| r.status == 'rejected' }
    @total_pending = @pending_referrals.count
    @total_reward_amount = @approved_referrals.sum(&:reward_amount)

    # Filter by status if provided
    @referrals = case params[:status]
                when 'pending'
                  @pending_referrals
                when 'approved'
                  @approved_referrals
                when 'rejected'
                  @rejected_referrals
                else
                  @referrals
                end

    @referrals = @referrals.first(20) # Simple limit instead of pagination for now
  end

  def show
    @affiliate = @referral.affiliate
  end

  def approve
    @referral.approve!
    redirect_to admin_referral_path(@referral), notice: 'Referral has been approved and reward credited.'
  end

  def reject
    reason = params[:reason] || 'Rejected by admin'
    @referral.reject!(reason)
    redirect_to admin_referral_path(@referral), notice: 'Referral has been rejected.'
  end

  private

  def set_referral
    @referral = Referral.find(params[:id])
  end

end