module Pay
  module Razorpay
    class Subscription
      attr_accessor :razorpay_subscription
      attr_reader :pay_subscription

      delegate :active?,
        :canceled?,
        :on_grace_period?,
        :on_trial?,
        :ends_at,
        :owner,
        :processor_subscription,
        :processor_id,
        :prorate,
        :processor_plan,
        :quantity?,
        :quantity,
        to: :pay_subscription

      def self.sync(subscription_id, object: nil, name: nil, try: 0, retries: 1)
        # Skip loading the latest subscription details from the API if we already have it
        object ||= ::Razorpay::Subscription.fetch(subscription_id)
        
        pay_customer = Pay::Customer.find_by(processor: :razorpay, processor_id: object.customer_id)
        return unless pay_customer
        
        attributes = {
          created_at: Time.at(object.created_at),
          processor_plan: object.plan_id,
          quantity: object.quantity,
          status: object.status,
          metadata: object.notes,
          subscription_items: [],
          metered: false,
          current_period_start: (object.current_start ? Time.at(object.current_start) : nil),
          current_period_end: (object.current_end ? Time.at(object.current_end) : nil)
        }


        # Razorpay Subscription API does not provide a built-in feature to handle trial periods. 
        # we can use start_at to handle trial period
        if object.start_at
          attributes[:trial_ends_at] = Time.at(object.start_at)
        end

        # Canceled subscriptions should have access through the paid_through_date or updated_at
        if object.status == "cancelled"
          attributes[:ends_at] = object.end_at
        end

        pay_subscription = pay_customer.subscriptions.find_by(processor_id: object.id)

        if pay_subscription
          pay_subscription.with_lock { pay_subscription.update!(attributes) }
        else
          name ||= Pay.default_product_name
          pay_subscription = pay_customer.subscriptions.create!(attributes.merge(name: name, processor_id: object.id))
        end

        pay_subscription
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        if try <= retries
          sleep 0.1
          retry
        else
          raise
        end
      end

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def subscription(**options)
        options[:id] = processor_id
        @razorpay_subscription ||= ::Razorpay::Subscription.fetch(processor_id)
      end


      def cancel(**options)
        @razorpay_subscription = ::Razorpay::Subscription.cancel(processor_id,{cancel_at_cycle_end: 1})
        
        pay_subscription.update(ends_at: (on_trial? ? trial_ends_at : Time.at(@razorpay_subscription.current_end)))
      rescue ::Razorpay::BadRequestError => e
        raise Pay::Razorpay::Error, e
      end

      # Cancels a subscription immediately
      #
      # cancel_now!(prorate: true)
      # cancel_now!(invoice_now: true)
      def cancel_now!(**options)
        @razorpay_subscription = ::Razorpay::Subscription.cancel(processor_id,{cancel_at_cycle_end: 0})
        pay_subscription.update(ends_at: Time.current, status: :canceled)
      rescue ::Razorpay::BadRequestError => e
        raise Pay::Razorpay::Error, e
      end

      def change_quantity(quantity, **options)
        pay_subscription.update(quantity: quantity)
      end

      def on_grace_period?
        canceled? && Time.current < ends_at
      end

      def paused?
        pay_subscription.status == "paused"
      end

      def pause
        pay_subscription.update(status: :paused, trial_ends_at: Time.current)
      end

      def resume
        unless paused?
          raise StandardError, "You can only resume paused subscriptions."
        end
        unless on_grace_period? || paused?
          raise StandardError, "You can only resume subscriptions within their grace period."
        end
      end

      def swap(plan, **options)
        pay_subscription.update(processor_plan: plan, ends_at: nil, status: :active)
      end

      # Retries the latest invoice for a Past Due subscription
      def retry_failed_payment
        pay_subscription.update(status: :active)
      end
    end
  end
end
