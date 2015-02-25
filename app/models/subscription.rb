class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  # accepts_nested_attributes_for :user, reject_if: :not_valid_user?

  attr_accessor :stripe_card_token
  attr_accessor :stripe_plan_id

  validates :stripe_customer_token, :presence => true, :message => 'Stripe Error'

  def save_with_stripe!(stripe_plan = (stripe_plan_id.present? ? stripe_plan_id : false ) || plan_id )
    # It has dynamic stripe plan variable if it exists either set
    # through controller or already on user or passed on call
    # which allows us to use it as upgrade as well.

    valid_params = (user.email && stripe_plan_id.present? && stripe_card_token.present?)

    if valid_params

      # Create customer and Set Card
      customer = Stripe::Customer.create(email: user.email, plan: stripe_plan_id, card: stripe_card_token)
      # Save Plan, Status and Customer Token
      self.update({plan_id: stripe_plan_id, status: 'active', stripe_customer_token: customer.id})

    elsif stripe_customer_token.present?

      customer = Stripe::Customer.retrieve(stripe_customer_token)

      customer.subscriptions.create(plan: stripe_plan)

      plan = Plan.find_by_name(stripe_plan)

      self.update(plan_id: plan, status:'active')

      self.save!

    else

      return false

    end

    # rescue Stripe::InvalidRequestError => e
    #   logger.error "Stripe error while creating customer: #{e.message}"
    #   error = 'There was a problem with your credit card.'
    #   return false

  end

  def unsubscribe_with_stripe
    customer = Stripe::Customer.retrieve(stripe_customer_token)
    sub_id = customer.subscriptions.data.find{|sub| sub[:plan][:id] == plan_id.to_s}[:id]
    delete = customer.subscriptions.retrieve(sub_id).delete
    if delete[:status] == 'canceled'
      self.update(status: 'cancelled') # Canceled has one 'l' but sticking to established values
    end

  end

  def active?
    case status
      when 'active'
        true
      when 'canceled' || 'cancelled'
        false
      else
        false
    end
  end
  
end
