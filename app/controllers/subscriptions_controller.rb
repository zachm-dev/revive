class SubscriptionsController < ApplicationController
  before_action :authorize
  before_action :set_subscription, only: [:show, :edit, :update, :destroy]

  def index
  end

  def new
    render layout: 'checkout'
    # For ~> checkout
    # If the user already has a plan just redirect to dash
    # in the future this will redirect to account and billing.
    # if current_user.subscription.plan_id.present?
    #   redirect_to dashboard_path
    # end
  end

  def create

    @subscription = Subscription.new(user: current_user, stripe_card_token: params['stripeToken'])

    # Plan
    plan = Plan.find_by_name(subscription_params[:plan_id])
    @subscription.plan = plan

    # User Info
    user_params = subscription_params[:user]

    # Set stripe stuff.
    @subscription.stripe_plan_id = subscription_params[:plan_id]
    @subscription.stripe_card_token = subscription_params[:stripeToken]

    respond_to do |format|

      if plan.present? && @subscription.save_with_stripe!
        # After Successful billing update stripe user with billing details if they are present
        # @subscription.user.update(user_params) if user_params.present?
        @subscription.user.update(user_params)
        format.html { redirect_to '/dashboard', notice: 'Subscription Successful. Welcome to Revive!' }
      elsif plan.present? == false
        format.html { redirect_to '/dashboard', error: 'Invalid Plan ID' }
      else
        format.html { redirect_to new_subscriptions_path, error: 'Subscription Failed.'}
      end

    end

  end

  def destroy
    respond_to do |format|
      if @subscription.unsubscribe_with_stripe
        format.html { redirect_to dashboard_path, success: 'Successfully Canceled Subscription. We will miss you ' + "#{current_user.first_name}! :(" }
      else
        format.html { redirect_to dashboard_path, error: 'Subscription Cancel Failed.'}
      end
    end
  end

  private

  def set_subscription
    @subscription = current_user.subscription
  end

  # Strong Params;
  # Never Trust Anything From The Pesky Interwebs for Users Are Cunning And [REDACTED]

  def subscription_params
    params.permit(:stripeToken, :plan_id, {user:[:first_name, :last_name, :phone, :email, :address_1, :address_2, :city, :zip, :state, :country]}, {card:[:number, :cvc, :month, :year]})
  end

end


