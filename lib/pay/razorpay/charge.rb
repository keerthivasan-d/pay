module Pay
  module Razorpay
    class Charge
      attr_reader :pay_charge

      delegate :amount,
        :amount_captured,
        :invoice_id,
        :line_items,
        :payment_intent_id,
        :processor_id,
        :stripe_account,
        to: :pay_charge

      def self.sync(payment_id, object: nil, try: 0, retries: 1)
        # Skip loading the latest charge details from the API if we already have it
        object ||= ::Razorpay::Payment.fetch(payment_id)

        # Ignore charges without a Customer
        return if object.customer_id.blank?

        pay_customer = Pay::Customer.find_by(processor: :razorpay, processor_id: object.customer_id)
        return unless pay_customer

        refunds = []
        object.refunds.items.each { |refund| refunds << refund }


        att = {
          amount: object.amount,
          amount_captured: object.amount,
          amount_refunded: object.amount_refunded,
          created_at: Time.at(object.created_at),
          currency: object.currency,
          discounts: [],
          line_items: [],
          metadata: object.notes,
          payment_method_type: object.method,
          total_tax_amounts: [],
          refunds: refunds.sort_by! { |r| r["created_at"] }
        }

        attrs = att.merge(payment_method_details_for(object))

        # Associate charge with subscription if we can
        if object.invoice_id
          invoice = ::Razorpay::Invoice.fetch(object.invoice_id)
          attrs[:invoice_id] = invoice.id
          attrs[:subscription] = pay_customer.subscriptions.find_by(processor_id: invoice.subscription_id)


          attrs[:period_start] = Time.at(invoice.billing_start)
          attrs[:period_end] = Time.at(invoice.billing_end)

          attrs[:subtotal] = invoice.amount_paid
          attrs[:total_tax_amounts] = invoice.tax_amount

          invoice.line_items.each do |line_item|
            line_item = to_recursive_ostruct(line_item)
            # Currency is tied to the charge, so storing it would be duplication
            attrs[:line_items] << {
              id: line_item.id,
              name: line_item.name,
              description: line_item.description,
              quantity: line_item.quantity,
              unit_amount: line_item.unit_amount,
              amount: line_item.amount,
              net_amount: line_item.net_amount,
              gross_amount: line_item.gross_amount,
              tax_amount: line_item.tax_amount,
              taxable_amount: line_item.taxable_amount,
              tax_inclusive: line_item.tax_inclusive
            }
          end
        # Charges without invoices
        else
          attrs[:period_start] = Time.at(object.created_at)
          attrs[:period_end] = Time.at(object.created_at)
        end

        # Update or create the charge
        if (pay_charge = pay_customer.charges.find_by(processor_id: object.id))
          pay_charge.with_lock do
            pay_charge.update!(attrs)
          end
          pay_charge
        else
          pay_customer.charges.create!(attrs.merge(processor_id: object.id))
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        try += 1
        if try <= retries
          sleep 0.1
          retry
        else
          raise
        end
      end

      def initialize(pay_charge)
        @pay_charge = pay_charge
      end

      # def charge
      #   ::Stripe::Charge.retrieve({id: processor_id, expand: ["customer", "invoice.subscription"]}, stripe_options)
      # rescue ::Stripe::StripeError => e
      #   raise Pay::Stripe::Error, e
      # end

      # Issues a CreditNote if there's an invoice, otherwise uses a Refund
      # This allows Tax to be handled properly
      #
      # https://stripe.com/docs/api/credit_notes/create
      # https://stripe.com/docs/api/refunds/create
      #
      # refund!
      # refund!(5_00)
      # refund!(5_00, refund_application_fee: true)
      # def refund!(amount_to_refund, **options)
      #   if invoice_id.present?
      #     description = options.delete(:description) || I18n.t("pay.refund")
      #     lines = [{type: :custom_line_item, description: description, quantity: 1, unit_amount: amount_to_refund}]
      #     credit_note!(**options.merge(refund_amount: amount_to_refund, lines: lines))
      #   else
      #     ::Stripe::Refund.create(options.merge(charge: processor_id, amount: amount_to_refund), stripe_options)
      #   end
      #   pay_charge.update!(amount_refunded: pay_charge.amount_refunded + amount_to_refund)
      # rescue ::Stripe::StripeError => e
      #   raise Pay::Stripe::Error, e
      # end

      # Adds a credit note to a Stripe Invoice
      # def credit_note!(**options)
      #   raise Pay::Stripe::Error, "no Stripe invoice_id on Pay::Charge" if invoice_id.blank?
      #   ::Stripe::CreditNote.create({invoice: invoice_id}.merge(options), stripe_options)
      # rescue ::Stripe::StripeError => e
      #   raise Pay::Stripe::Error, e
      # end

      # def credit_notes(**options)
      #   raise Pay::Stripe::Error, "no Stripe invoice_id on Pay::Charge" if invoice_id.blank?
      #   ::Stripe::CreditNote.list({invoice: invoice_id}.merge(options), stripe_options)
      # end

      # https://stripe.com/docs/payments/capture-later
      #
      # capture
      # capture(amount_to_capture: 15_00)
      # def capture(**options)
      #   raise Pay::Stripe::Error, "no payment_intent_id on charge" unless payment_intent_id.present?
      #   ::Stripe::PaymentIntent.capture(payment_intent_id, options, stripe_options)
      #   self.class.sync(processor_id)
      # rescue ::Stripe::StripeError => e
      #   raise Pay::Stripe::Error, e
      # end

      # private

      # # Options for Stripe requests
      # def stripe_options
      #   {stripe_account: stripe_account}.compact
      # end

      def self.payment_method_details_for(payment)
        case payment.method
        when "card"
          {
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
            bank: payment.bank
          }
        when "upi"
          {
            payment_method_type: :upi,
            brand: payment.vpa || 'upi'
          }                    
        else
          {}
        end
      end

      def self.to_recursive_ostruct(hash)
        result = hash.each_with_object({}) do |(key, val), memo|
          memo[key] = val.is_a?(Hash) ? to_recursive_ostruct(val) : val
        end
        OpenStruct.new(result)
      end
    end
  end
end
