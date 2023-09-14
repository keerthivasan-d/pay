module Pay
  module CcavenueGateway
    # autoload :Billable, "pay/ccavenue_gateway/billable"
    # autoload :Charge, "pay/ccavenue_gateway/charge"
    # autoload :Error, "pay/ccavenue_gateway/error"
    # autoload :PaymentMethod, "pay/ccavenue_gateway/payment_method"
    # autoload :Subscription, "pay/ccavenue_gateway/subscription"
    # autoload :Merchant, "pay/ccavenue_gateway/merchant"

    module Webhooks
      # autoload :PaymentCaptured, "pay/ccavenue_gateway/webhooks/payment_captured"
      # autoload :PaymentFailed, "pay/ccavenue_gateway/webhooks/payment_failed"
      # autoload :SubscriptionAuthenticated, "pay/ccavenue_gateway/webhooks/subscription_authenticated"
    end

    extend Env

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:ccavenue) && defined?(::CcavenueGateway)

      true
    end

    # def self.setup
    #   ::Razorpay.setup(public_key, private_key)
    # end

    # def self.public_key
    #   find_value_by_name(:razorpay, :public_key)
    # end

    # def self.private_key
    #   find_value_by_name(:razorpay, :private_key)
    # end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        # Listen to the charge event to make sure we get non-subscription
        # purchases as well. Invoice is only for subscriptions and manual creation
        # so it does not include individual charges.
        # events.subscribe "razorpay.payment.captured", Pay::Razorpay::Webhooks::PaymentCaptured.new
        # events.subscribe "razorpay.payment.failed", Pay::Razorpay::Webhooks::PaymentFailed.new
        # events.subscribe "razorpay.subscription.authenticated", Pay::Razorpay::Webhooks::SubscriptionAuthenticated.new

        # events.subscribe "stripe.charge.refunded", Pay::Stripe::Webhooks::ChargeRefunded.new

        # events.subscribe "stripe.payment_intent.succeeded", Pay::Stripe::Webhooks::PaymentIntentSucceeded.new

        # # Warn user of upcoming charges for their subscription. This is handy for
        # # notifying annual users their subscription will renew shortly.
        # # This probably should be ignored for monthly subscriptions.
        # events.subscribe "stripe.invoice.upcoming", Pay::Stripe::Webhooks::SubscriptionRenewing.new

        # # Payment action is required to process an invoice
        # events.subscribe "stripe.invoice.payment_action_required", Pay::Stripe::Webhooks::PaymentActionRequired.new

        # # If an invoice payment fails, we want to notify the user via email to update their payment details
        # events.subscribe "stripe.invoice.payment_failed", Pay::Stripe::Webhooks::PaymentFailed.new

        # # If a subscription is manually created on Stripe, we want to sync
        # events.subscribe "stripe.customer.subscription.created", Pay::Stripe::Webhooks::SubscriptionCreated.new

        # # If the plan, quantity, or trial ending date is updated on Stripe, we want to sync
        # events.subscribe "stripe.customer.subscription.updated", Pay::Stripe::Webhooks::SubscriptionUpdated.new

        # # When a customers subscription is canceled, we want to update our records
        # events.subscribe "stripe.customer.subscription.deleted", Pay::Stripe::Webhooks::SubscriptionDeleted.new

        # # When a customers subscription trial period is 3 days from ending or ended immediately this event is fired
        # events.subscribe "stripe.customer.subscription.trial_will_end", Pay::Stripe::Webhooks::SubscriptionTrialWillEnd.new

        # # Monitor changes for customer's default card changing
        # events.subscribe "stripe.customer.updated", Pay::Stripe::Webhooks::CustomerUpdated.new

        # # If a customer was deleted in Stripe, their subscriptions should be cancelled
        # events.subscribe "stripe.customer.deleted", Pay::Stripe::Webhooks::CustomerDeleted.new

        # # If a customer's payment source was deleted in Stripe, we should update as well
        # events.subscribe "stripe.payment_method.attached", Pay::Stripe::Webhooks::PaymentMethodAttached.new
        # events.subscribe "stripe.payment_method.updated", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        # events.subscribe "stripe.payment_method.card_automatically_updated", Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        # events.subscribe "stripe.payment_method.detached", Pay::Stripe::Webhooks::PaymentMethodDetached.new

        # # If an account is updated in stripe, we should update it as well
        # events.subscribe "stripe.account.updated", Pay::Stripe::Webhooks::AccountUpdated.new

        # # Handle subscriptions in Stripe Checkout Sessions
        # events.subscribe "stripe.checkout.session.completed", Pay::Stripe::Webhooks::CheckoutSessionCompleted.new
        # events.subscribe "stripe.checkout.session.async_payment_succeeded", Pay::Stripe::Webhooks::CheckoutSessionAsyncPaymentSucceeded.new
      end
    end

  end
end
