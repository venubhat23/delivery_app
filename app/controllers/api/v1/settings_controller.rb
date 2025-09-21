module Api
  module V1
    class SettingsController < BaseController
      before_action :authenticate_request

      # GET /api/v1/settings
      def index
        admin = AdminSetting.first
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer

        faq_summary = {
          categories: Faq.published.for_locale(params[:locale] || 'en').group(:category).count.map { |cat, cnt| { title: cat, count: cnt } },
        }

        cms = build_cms_metadata(params[:locale] || 'en')
        referral = build_referral(customer)
        delivery_preferences = build_delivery_preferences(customer)
        addresses = build_addresses(customer)
        app_settings = build_app_settings(customer)
        contact = build_contact(admin)

        render json: {
          user: user_summary(customer),
          appSettings: app_settings,
          deliveryPreferences: delivery_preferences,
          addresses: addresses,
          referral: referral,
          faq: faq_summary,
          cms: cms,
          contact: contact
        }, status: :ok
      end

      # GET /api/v1/settings/faq
      def faq
        faqs = Faq.published.for_locale(params[:locale] || 'en').ordered
        render json: faqs.as_json(only: [:id, :category, :question, :answer, :locale, :sort_order]), status: :ok
      end

      # POST /api/v1/settings/faq/ask
      def ask_question
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        return render json: { error: 'Customer not found' }, status: :not_found unless customer

        faq = customer.faqs.build(
          question: params[:question],
          category: params[:category] || 'general',
          locale: params[:locale] || 'en',
          submitted_by_user: true,
          status: :pending,
          is_active: false
        )

        if faq.save
          render json: { 
            message: 'Question submitted successfully', 
            faq_id: faq.id,
            status: 'pending'
          }, status: :created
        else
          render json: { errors: faq.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/settings/cms/terms-of-service
      def terms
        page = CmsPage.published.for_slug('terms-of-service').for_locale(params[:locale] || 'en').order(published_at: :desc).first
        return render json: { error: 'Terms not found' }, status: :not_found unless page
        render json: page.as_json(only: [:slug, :version, :title, :content, :locale, :published_at]), status: :ok
      end

      # GET /api/v1/settings/cms/privacy-policy
      def privacy
        page = CmsPage.published.for_slug('privacy-policy').for_locale(params[:locale] || 'en').order(published_at: :desc).first
        return render json: { error: 'Privacy policy not found' }, status: :not_found unless page
        render json: page.as_json(only: [:slug, :version, :title, :content, :locale, :published_at]), status: :ok
      end

      # GET /api/v1/settings/referral
      def referral
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        render json: build_referral(customer), status: :ok
      end

      # GET /api/v1/settings/delivery-preferences
      def delivery_preferences
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        render json: build_delivery_preferences(customer), status: :ok
      end

      # POST /api/v1/settings/contact
      def contact
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        return render json: { error: 'Customer not found' }, status: :not_found unless customer

        ticket = customer.support_tickets.build(
          subject: params[:subject],
          message: params[:message],
          channel: 'app',
          priority: params[:priority] || 'low',
          status: 'open'
        )

        if ticket.save
          render json: { 
            message: 'Support request submitted successfully', 
            ticket_id: ticket.id,
            status: 'open'
          }, status: :created
        else
          render json: { errors: ticket.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/settings/preferences
      def update_preferences
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        return render json: { error: 'Customer not found' }, status: :not_found unless customer

        preferences = customer.preferences
        
        if preferences.update(preference_params)
          render json: { 
            message: 'Preferences updated successfully',
            preferences: build_delivery_preferences(customer)
          }, status: :ok
        else
          render json: { errors: preferences.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/settings/language
      def update_language
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        return render json: { error: 'Customer not found' }, status: :not_found unless customer

        preferences = customer.preferences
        
        if preferences.update(language: params[:language])
          render json: { 
            message: 'Language updated successfully',
            language: preferences.language
          }, status: :ok
        else
          render json: { errors: preferences.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/settings/addresses
      def addresses
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        return render json: { error: 'Customer not found' }, status: :not_found unless customer

        addresses = customer.customer_addresses.order(is_default: :desc, created_at: :desc)
        render json: addresses.as_json(
          only: [:id, :address_type, :street_address, :city, :state, :pincode, :landmark, :is_default],
          methods: [:full_address, :short_address]
        ), status: :ok
      end

      # POST /api/v1/settings/addresses
      def create_address
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        return render json: { error: 'Customer not found' }, status: :not_found unless customer

        address = customer.customer_addresses.build(address_params)

        if address.save
          render json: { 
            message: 'Address created successfully',
            address: address.as_json(
              only: [:id, :address_type, :street_address, :city, :state, :pincode, :landmark, :is_default],
              methods: [:full_address, :short_address]
            )
          }, status: :created
        else
          render json: { errors: address.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/settings/addresses/:id
      def update_address
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        return render json: { error: 'Customer not found' }, status: :not_found unless customer

        address = customer.customer_addresses.find(params[:id])

        if address.update(address_params)
          render json: { 
            message: 'Address updated successfully',
            address: address.as_json(
              only: [:id, :address_type, :street_address, :city, :state, :pincode, :landmark, :is_default],
              methods: [:full_address, :short_address]
            )
          }, status: :ok
        else
          render json: { errors: address.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/settings/addresses/:id
      def delete_address
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        return render json: { error: 'Customer not found' }, status: :not_found unless customer

        address = customer.customer_addresses.find(params[:id])
        address.destroy

        render json: { message: 'Address deleted successfully' }, status: :ok
      end

      # POST /api/v1/settings/addresses/:id/set_default
      def set_default_address
        customer = current_user.is_a?(Customer) ? current_user : current_user&.customer
        return render json: { error: 'Customer not found' }, status: :not_found unless customer

        address = customer.customer_addresses.find(params[:id])
        address.set_as_default!

        render json: { 
          message: 'Default address updated successfully',
          address: address.as_json(
            only: [:id, :address_type, :street_address, :city, :state, :pincode, :landmark, :is_default],
            methods: [:full_address, :short_address]
          )
        }, status: :ok
      end

      private

      def build_cms_metadata(locale)
        terms = CmsPage.published.for_slug('terms-of-service').for_locale(locale).order(published_at: :desc).first
        privacy = CmsPage.published.for_slug('privacy-policy').for_locale(locale).order(published_at: :desc).first
        {
          termsOfService: terms ? { version: terms.version, lastUpdated: terms.published_at, url: nil } : nil,
          privacyPolicy: privacy ? { version: privacy.version, lastUpdated: privacy.published_at, url: nil } : nil
        }
      end

      def build_referral(customer)
        return nil unless customer
        ref = ReferralCode.find_by(customer_id: customer.id)
        if ref.nil?
          # Generate a simple unique code if not present
          code = loop do
            candidate = SecureRandom.alphanumeric(8).upcase
            break candidate unless ReferralCode.exists?(code: candidate)
          end
          ref = ReferralCode.create!(customer_id: customer.id, code: code, share_url_slug: code)
        end
        {
          code: ref.code,
          shareUrl: ref.share_url(request.base_url),
          creditsEarned: ref.total_credits,
          referralsCount: ref.total_referrals
        }
      end

      def build_delivery_preferences(customer)
        return nil unless customer
        
        preferences = customer.preferences
        {
          timeWindow: {
            start: preferences.delivery_time_start&.strftime('%H:%M'),
            end: preferences.delivery_time_end&.strftime('%H:%M')
          },
          skipWeekends: preferences.skip_weekends,
          specialInstructions: preferences.special_instructions,
          notificationPreferences: preferences.notification_settings,
          deliveryTimePreference: customer.delivery_time_preference
        }
      end

      def build_addresses(customer)
        return [] unless customer
        
        customer.customer_addresses.order(is_default: :desc, created_at: :desc).map do |address|
          {
            id: address.id,
            addressType: address.address_type,
            streetAddress: address.street_address,
            city: address.city,
            state: address.state,
            pincode: address.pincode,
            landmark: address.landmark,
            isDefault: address.is_default,
            fullAddress: address.full_address,
            shortAddress: address.short_address
          }
        end
      end

      def build_app_settings(customer)
        return nil unless customer
        
        preferences = customer.preferences
        {
          language: preferences.language || 'en',
          notificationPreferences: preferences.notification_settings,
          theme: 'light' # Default theme, can be extended
        }
      end

      def build_contact(admin)
        {
          email: admin&.email,
          phone: admin&.mobile
        }
      end

      def user_summary(customer)
        if current_user.is_a?(Customer)
          { id: current_user.id, name: current_user.name }
        elsif current_user.is_a?(User) && customer
          { id: customer.id, name: customer.name }
        else
          { id: current_user.id, name: current_user.name }
        end
      end

      def authenticate_request
        # Add your authentication logic here
        # This should validate JWT tokens or API keys
        head :unauthorized unless current_user
      end

      def preference_params
        params.permit(:language, :delivery_time_start, :delivery_time_end, :skip_weekends, 
                     :special_instructions, notification_preferences: {})
      end

      def address_params
        params.permit(:address_type, :street_address, :city, :state, :pincode, :landmark, :is_default)
      end
    end
  end
end