class Razorpay::SubscriptionsController < ApplicationController
  before_action :set_subscription, only: [:show, :edit, :update, :destroy, :cancel, :resume]

  def index
    @subscriptions = Pay::Subscription.joins(:customer).where(pay_customers: {processor: :razorpay}).order(created_at: :desc)
  end

  def show
  end

  def new
  end

  def create
    raise params.to_json
    current_user.set_payment_processor params[:processor]
    current_user.payment_processor.payment_method_token = params[:card_token]
    subscription = current_user.payment_processor.subscribe(plan: params[:plan_id])
    redirect_to paddle_subscription_path(subscription)
  rescue Pay::Error => e
    flash[:alert] = e.message
    redirect_to new_razorpay_subscription_path
  end

  def edit
  end

  def update
  end

  def destroy
    @subscription.cancel_now!
    redirect_to paddle_subscription_path(@subscription)
  end

  def cancel
    @subscription.cancel
    redirect_to paddle_subscription_path(@subscription)
  end

  def resume
    @subscription.resume
    redirect_to paddle_subscription_path(@subscription)
  end

  private

  def set_subscription
    @subscription = Pay::Subscription.find(params[:id])
  end
end
