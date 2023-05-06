module Pay
  module Razorpay
    class PaymentMethod
      attr_reader :pay_payment_method

      delegate :customer, :processor_id, to: :pay_payment_method
      
      # Razorpay doesn't provide PaymentMethod IDs, so we have to lookup via the Payment
      def self.sync(payment_id, object: nil, try: 0, retries: 1)
        # Skip loading the latest charge details from the API if we already have it
        object ||= ::Razorpay::Payment.fetch(payment_id)

        # Ignore charges without a Customer
        return if object.customer_id.blank?

        pay_customer = Pay::Customer.find_by(processor: :razorpay, processor_id: object.customer_id)
        return unless pay_customer

        payment_method = pay_customer.default_payment_method || pay_customer.build_default_payment_method

        payment_method.processor_id ||= NanoId.generate

        attributes ||= payment_method_details_for(object)

        payment_method.update!(attributes)
        payment_method
      rescue ::Razorpay::BadRequestError => e
        raise Pay::Razorpay::Error, e
      end

      def self.payment_method_details_for(payment)
        case payment.method
        when "card"
          {
            processor_id: payment.card['id'],
            payment_method_type: :card,
            brand: payment.card['network'],
            last4: payment.card['last4']
          }
        when "wallet"
          {
            payment_method_type: :wallet,
            brand: payment.wallet
          }
        when "netbanking"
          {
            payment_method_type: :netbanking,
            brand: payment.bank
          }
        when "upi"
          {
            payment_method_type: :upi,
            brand: payment.vpa
          }                    
        else
          {}
        end
      end

      def initialize(pay_payment_method)
        @pay_payment_method = pay_payment_method
      end

      # Sets payment method as default
      def make_default!
      end

      # Remove payment method
      def detach
      end
    end
  end
end
