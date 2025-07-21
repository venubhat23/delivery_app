class AdminSettingsController < ApplicationController
  before_action :require_login
  before_action :set_admin_setting, only: [:show, :edit, :update, :destroy]

  def index
    @admin_setting = AdminSetting.first || AdminSetting.new
    redirect_to @admin_setting if @admin_setting.persisted?
  end

  def show
    generate_qr_code if @admin_setting.upi_id.present?
  end

  def new
    @admin_setting = AdminSetting.new
    set_default_values
  end

  def create
    @admin_setting = AdminSetting.new(admin_setting_params)
    
    if @admin_setting.save
      generate_qr_code if @admin_setting.upi_id.present?
      redirect_to @admin_setting, notice: 'Admin settings were successfully created.'
    else
      render :new
    end
  end

  def edit
    # Set default brand name if empty
    if @admin_setting.business_name.blank?
      @admin_setting.business_name = current_user&.name || "Atma Nirbhar Farm"
    end
  end

  def update
    if @admin_setting.update(admin_setting_params)
      generate_qr_code if @admin_setting.upi_id.present?
      redirect_to @admin_setting, notice: 'Admin settings were successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @admin_setting.destroy
    redirect_to admin_settings_path, notice: 'Admin settings were successfully deleted.'
  end

  private

  def set_admin_setting
    @admin_setting = AdminSetting.find(params[:id])
  end

  def admin_setting_params
    params.require(:admin_setting).permit(:business_name, :address, :mobile, :email, :gstin, :pan_number,
                                          :account_holder_name, :bank_name, :account_number, :ifsc_code,
                                          :upi_id, :terms_and_conditions)
  end

  def set_default_values
    @admin_setting.business_name = current_user&.name || "Atma Nirbhar Farm"
    @admin_setting.account_holder_name = current_user&.name || "Atma Nirbhar Farm"
    @admin_setting.bank_name = "Canara Bank"
    @admin_setting.account_number = "3194201000718"
    @admin_setting.ifsc_code = "CNRB0003194"
    @admin_setting.terms_and_conditions = "Kindly make your monthly payment on or before the 10th of every month.\nPlease share the payment screenshot immediately after completing the transaction to confirm your payment."
  end

  def generate_qr_code
    require 'rqrcode'
    
    qr = RQRCode::QRCode.new(@admin_setting.upi_id)
    
    # Generate SVG
    svg = qr.as_svg(
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 6,
      standalone: true
    )
    
    # Save to storage
    qr_code_path = Rails.root.join('public', 'qr_codes')
    FileUtils.mkdir_p(qr_code_path) unless Dir.exist?(qr_code_path)
    
    File.write(Rails.root.join('public', 'qr_codes', "upi_qr_#{@admin_setting.id}.svg"), svg)
    
    @admin_setting.update(qr_code_path: "/qr_codes/upi_qr_#{@admin_setting.id}.svg")
  end
end