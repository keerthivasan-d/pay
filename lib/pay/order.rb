module Pay
  class Order
    attr_reader :order

    delegate :id, :amount, :receipt, :currency, :status, :notes, to: :order

    def self.from_id(id)
      order = ::Razorpay::Order.fetch(id)
      new(order)
    end

    def initialize(order)
      @order = order
    end

    def created?
      status == "created"
    end

    def attempted?
      status == "attempted"
    end

    def paid?
      status == "paid"
    end

    def amount_with_currency
      Pay::Currency.format(amount, currency: currency)
    end

  end
end
