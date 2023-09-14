module Pay
  module Razorpay
    module Webhooks
      class PaymentFailed
        def call(event)
          if event.contains.include?('payment')
            payment = event.payload.payment.entity
            pay_charge = Pay::Razorpay::Charge.sync(payment.id)
            if pay_charge && Pay.send_email?(:receipt, pay_charge)
              Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).receipt.deliver_later
            end
          end
        end
      end
    end
  end
end
