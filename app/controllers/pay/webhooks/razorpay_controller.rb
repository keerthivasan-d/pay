module Pay
  module Webhooks
    class RazorpayController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end
      # KrNDrN@Pz9km9Vn
      #2 unKef-wu3$RkD3q
      def create
        queue_event(verified_event)
        head :ok
      # rescue ::Razorpay::SecurityError => e
      #   log_error(e)
      #   head :bad_request
      end

      private

      def queue_event(event)
        record = Pay::Webhook.create!(processor: :razorpay, event_type: event['event'], event: event)
        Pay::Webhooks::ProcessJob.perform_later(record)
      end

      def verified_event
        webhook_secret = 'unKef-wu3$RkD3q'
        webhook_body = request.raw_post
        webhook_signature = request.headers["X-Razorpay-Signature"]
        webhook_verify_signature = ::Razorpay::Utility.verify_webhook_signature(webhook_body, webhook_signature, webhook_secret)
        return verify_params if webhook_verify_signature
        raise Pay::Razorpay::Error, "Unable to verify Razorpay webhook event"
      end

      def verify_params
        params.except(:action, :controller).permit!
      end

      def log_error(e)
        logger.error e.message
        e.backtrace.each { |line| logger.error "  #{line}" }
      end
    end
  end
end
