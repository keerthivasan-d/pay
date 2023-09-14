module Pay
  module Razorpay
    class Billable
      attr_reader :pay_customer

      delegate :processor_id,
        :processor_id?,
        :email,
        :customer_name,
        :payment_method_token,
        :payment_method_token?,
        :phone_number,
        to: :pay_customer

      def initialize(pay_customer)
        @pay_customer = pay_customer
      end

      # Returns a hash of attributes for the Razorpay::Customer object
      def customer_attributes
        owner = pay_customer.owner
        
        attributes = case owner.class.pay_razorpay_customer_attributes
        when Symbol
          owner.send(owner.class.pay_razorpay_customer_attributes, pay_customer)
        when Proc
          owner.class.pay_razorpay_customer_attributes.call(pay_customer)
        end
        # Guard against attributes being returned nil
        attributes ||= {}
        attributes[:contact] = phone_number if phone_number.present?

        {email: email, name: customer_name}.merge(attributes)
      end

      # Retrieves a Razorpay::Customer object
      #
      # Finds an existing Razorpay::Customer if processor_id exists
      # Creates a new Razorpay::Customer using `customer_attributes` if empty processor_id
      #
      # Updates the default payment method automatically if a payment_method_token is set
      #
      # Returns a Razorpay::Customer object
      def customer
        razorpay_customer = if processor_id?
          ::Razorpay::Customer.fetch(processor_id)
        else
          rc = ::Razorpay::Customer.create(customer_attributes)
          pay_customer.update!(processor_id: rc.id)
          rc
        end

        if payment_method_token?
          add_payment_method(payment_method_token, default: true)
          pay_customer.payment_method_token = nil
        end

        razorpay_customer
      rescue ::Razorpay::BadRequestError => e
        raise Pay::Razorpay::Error, e
      end
      
      # Syncs name and email to Stripe::Customer
      # You can also pass in other attributes that will be merged into the default attributes
      def update_customer!(**attributes)
        customer unless processor_id?
        ::Razorpay::Customer.edit(
          processor_id,
          customer_attributes.merge(attributes)
        )
      end

      # def charge(amount, options = {})
      #   # Make to generate a processor_id
      #   customer

      #   attributes = options.merge(
      #     processor_id: NanoId.generate,
      #     amount: amount,
      #     data: {
      #       payment_method_type: :card,
      #       brand: "Fake",
      #       last4: 1234,
      #       exp_month: Date.today.month,
      #       exp_year: Date.today.year
      #     }
      #   )
      #   pay_customer.charges.create!(attributes)
      # end

      def charge(amount, options = {})
        add_payment_method(payment_method_token, default: true) if payment_method_token?

        payment_method = pay_customer.default_payment_method
        
        args = {
          amount: amount,
          confirm: true,
          currency: "usd",
          customer: customer.id,
          expand: ["latest_charge.refunds"],
          payment_method: payment_method&.processor_id
        }.merge(options)

        payment_intent = ::Razorpay::Order.create(args, stripe_options)
        Pay::Payment.new(payment_intent).validate

        charge = payment_intent.latest_charge
        Pay::Razorpay::Charge.sync(charge.id, object: charge)
      rescue ::Stripe::StripeError => e
        raise Pay::Stripe::Error, e
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # raise customer.id.to_json
        # raise options.to_json
        # quantity = options.delete(:quantity)

        trial_period_days = options.delete(:trial_period_days)
        promotion_code = options.delete(:promotion_code)
        
        opts = {
          plan_id: plan,
          customer_notify: 1, # send email/SMS notification to customer
          total_count: 12, # number of payments
        }.merge(options)

        # raise opts.to_json

        # Load the Stripe customer to verify it exists and update payment method if needed
        opts[:customer_id] = customer.id

        # Create subscription on Razorpay
        razorypay_sub = ::Razorpay::Subscription.create(opts)

        # Save Pay::Subscription
        subscription = Pay::Razorpay::Subscription.sync(razorypay_sub.id, object: razorypay_sub, name: name)

        # # No trial, payment method requires SCA
        # if options[:payment_behavior].to_s != "default_incomplete" && subscription.incomplete?
        #   Pay::Payment.new(stripe_sub.latest_invoice.payment_intent).validate
        # end

        subscription
      rescue ::Razorpay::BadRequestError => e
        raise Pay::Razorpay::Error, e
      end
        
      def create_order(options = {})
        options[:notes][:customer_id] = customer.id
        ::Razorpay::Order.create(options)
      rescue ::Razorpay::BadRequestError => e
        raise Pay::Razorpay::Error, e
      end
        
    

      def add_payment_method(payment_method_id, default: false)
        # Make to generate a processor_id
        customer

        pay_payment_method = pay_customer.payment_methods.create!(
          processor_id: NanoId.generate,
          default: default,
          type: :card,
          data: {
            brand: "Fake",
            last4: 1234,
            exp_month: Date.today.month,
            exp_year: Date.today.year
          }
        )

        pay_customer.reload_default_payment_method if default
        pay_payment_method
      end

      def processor_subscription(subscription_id, options = {})
        pay_customer.subscriptions.find_by(processor_id: subscription_id)
      end

      def trial_end_date(subscription)
        Date.today
      end
    end
  end
end
