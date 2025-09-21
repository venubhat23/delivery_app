module Api
  module V1
    class BankDetailsController < BaseController
      before_action :authenticate_request

      # GET /api/v1/bank_details
      def show
        @admin_setting = AdminSetting.first
        
        if @admin_setting.nil?
          render json: { error: 'Bank details not configured' }, status: :not_found
          return
        end

        generate_qr_code if @admin_setting.upi_id.present?

        bank_details = {
          business_name: @admin_setting.business_name,
          address: @admin_setting.address,
          mobile: @admin_setting.mobile,
          email: @admin_setting.email,
          gstin: @admin_setting.gstin,
          pan_number: @admin_setting.pan_number,
          account_holder_name: @admin_setting.account_holder_name,
          bank_name: @admin_setting.bank_name,
          account_number: @admin_setting.account_number,
          ifsc_code: @admin_setting.ifsc_code,
          upi_id: @admin_setting.upi_id,
          terms_and_conditions: @admin_setting.formatted_terms_and_conditions,
          qr_code_url: "https://file-upload-2024-milk-delivery.s3.ap-south-1.amazonaws.com/uploads/upi_qr_1.svg"
        }

        render json: { bank_details: bank_details }, status: :ok
      end

      private

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
  end
end