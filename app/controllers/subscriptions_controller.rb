class SubscriptionsController < ApplicationController
  before_action :authorize
  before_action :set_subscription, only: [:show, :edit, :update, :destroy]

  def index
  end

  def new
    @subscription = Subscription.new
    if params['plan_id'] == "1"
      @price = '199.00'
    else
      @price = '297.00'
    end
    # For ~> checkout
    # If the user already has a plan just redirect to dash
    # in the future this will redirect to account and billing.
    if !current_user.subscription.nil? && current_user.subscription.active?
      redirect_to '/account#subscription'
    else
      render layout: 'checkout'
    end
  end

  # New Stripe Subscription
  def create
    @subscription = Subscription.new(user: current_user, stripe_card_token: params['stripeToken'])

    # Plan
    plan = Plan.using(:main_shard).find_by_name(subscription_params[:plan_id].to_s)
    @subscription.plan = plan

    # User Info
    user_params = subscription_params[:user]

    # Set stripe stuff.
    @subscription.stripe_plan_id = subscription_params[:plan_id]
    @subscription.stripe_card_token = subscription_params[:stripeToken]
    @subscription.trial_end = subscription_params[:trial_end].to_i

    respond_to do |format|

      if plan.present? && @subscription.save_with_stripe!
        # After Successful billing update stripe user with billing details if they are present
        # @subscription.user.update(user_params) if user_params.present?
        @subscription.user.update(user_params)
        format.html { redirect_to '/dashboard', flash:{success: 'Subscription Successful. Welcome to Revive!' } }
      elsif plan.present? == false
        format.html { redirect_to new_subscriptions_path, flash:{error: 'Invalid Plan ID' } }
      else
        format.html { render action: :new, layout: 'checkout' }
      end

    end

  end

  # Re subscribe Stripe
  def update
    @subscription.stripe_plan_id = subscription_params[:plan_id] ||  @subscription.plan.name

    respond_to do |format|
      if @subscription.user == current_user && @subscription.subscribe_with_stripe
        format.html { redirect_to '/dashboard', flash:{success: 'Subscription Successful. Welcome to Back Revive!' } }
      else
        format.html { redirect_to '/account#subscription'}
      end
    end
  end

  # Unsubscribe From Stripe

  def destroy
    respond_to do |format|
      if @subscription.unsubscribe_with_stripe
        format.html { redirect_to dashboard_path, flash:{success: 'Successfully Canceled Subscription. \n We will miss you ' + "#{current_user.first_name}! :(" }}
      else
        format.html { redirect_to dashboard_path,  flash:{success: 'Subscription Cancel Failed.'} }
      end
    end
  end
  
  def create_trial_for_existing_customer
    if current_user.subscription && current_user.subscription.stripe_customer_token
      begin
        customer = Stripe::Customer.retrieve(current_user.subscription.stripe_customer_token)
        if customer
          customer.subscriptions.create(:plan => params['plan_id'], trial_end: params['trial_end'].to_i.days.from_now.to_time.to_i)
          current_user.subscription.status = 'active'
          current_user.subscription.trial_end = "#{params['trial_end'].to_i.days.from_now.to_time.to_i}"
          current_user.subscription.save
        end
        redirect_to dashboard_path, flash:{success: 'Subscription Successful. Welcome Back to Revive!' }
      rescue
        redirect_to dashboard_path, flash:{error: 'Subscription Unsuccessful' }
      end
    end
    
  end
  
  # def upgrade_to_charter
  #   customer = Stripe::Customer.retrieve({CUSTOMER_ID})
  #   subscription = customer.subscriptions.retrieve({SUBSCRIPTION_ID})
  #   subscription.plan = {PLAN_ID}
  #   subscription.save
  # end

  private

  def set_subscription
    @subscription = current_user.subscription
  end

  # Strong Params;
  # Never Trust Anything From The Pesky Interwebs for Users Are Cunning And [REDACTED]

  def subscription_params
    params.permit(:stripeToken, :plan_id, :trial_end, {user:[:first_name, :last_name, :phone, :email, :address_1, :address_2, :city, :zip, :state, :country]}, {card:[:number, :cvc, :month, :year]})
  end

end


