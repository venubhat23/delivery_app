class ReferralCodesController < ApplicationController
  before_action :set_referral_code, only: [:show, :destroy]
  before_action :authenticate_user!

  def index
    @referral_codes = ReferralCode.includes(:customer).recent
    @referral_codes = @referral_codes.active if params[:status] == 'active'
    @referral_codes = @referral_codes.with_referrals if params[:with_referrals] == 'true'
    @referral_codes = @referral_codes.with_credits if params[:with_credits] == 'true'
    
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @referral_codes = @referral_codes.joins(:customer)
                                     .where("referral_codes.code ILIKE ? OR customers.name ILIKE ?", search_term, search_term)
    end
    
    @referral_codes = @referral_codes.page(params[:page])
    
    @stats = {
      total_codes: ReferralCode.count,
      active_codes: ReferralCode.active.count,
      total_referrals: ReferralCode.total_referrals_count,
      total_credits: ReferralCode.total_credits_distributed
    }
  end

  def show
    @referral_history = []  # Add referral history if you have a referral transactions model
  end

  def destroy
    @referral_code.destroy
    redirect_to referral_codes_path, notice: 'Referral code was successfully deleted.'
  end

  def leaderboard
    @top_referrers = ReferralCode.leaderboard(20)
    render json: @top_referrers.as_json(
      include: { customer: { only: [:id, :name, :phone_number] } },
      only: [:code, :total_referrals, :total_credits]
    )
  end

  private

  def set_referral_code
    @referral_code = ReferralCode.find(params[:id])
  end
end