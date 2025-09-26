class OwnerNotificationMailer < ApplicationMailer
  default from: -> { AdminSetting.current.email || 'noreply@delivery.com' }

  def new_mobile_order(customer_name, order_details)
    @customer_name = customer_name
    @order_details = order_details
    @admin_settings = AdminSetting.current

    return unless @admin_settings.owner_email.present?

    mail(
      to: @admin_settings.owner_email,
      subject: "New Mobile Order from #{@customer_name}"
    )
  end

  def new_mobile_subscription(customer_name, subscription_details)
    @customer_name = customer_name
    @subscription_details = subscription_details
    @admin_settings = AdminSetting.current

    return unless @admin_settings.owner_email.present?

    mail(
      to: @admin_settings.owner_email,
      subject: "New Mobile Subscription from #{@customer_name}"
    )
  end
end