class SubscriptionsController < ApplicationController
  def index
  end

  def new
  end

  def create
    @subscription = Subscription.new(stripe_card_token: params['stripe_card_token'])
      if @subscription.save_with_payment
        redirect_to root_path, :notice => "Thank you for subscribing!"
      else
        redirect_to checkout_path
      end
  end
end
