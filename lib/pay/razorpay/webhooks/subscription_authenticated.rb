module Pay
  module Razorpay
    module Webhooks
      class SubscriptionAuthenticated
        def call(event)
          if event.contains.include?('subscription')
            subscription = event.payload.subscription.entity
            pay_charge = Pay::Razorpay::Subscription.sync(subscription.id)
          end
        end
      end
    end
  end
end
