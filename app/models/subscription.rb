# == Schema Information
#
# Table name: subscriptions
#
#  id                    :integer          not null, primary key
#  user_id               :integer
#  stripe_customer_token :string
#  status                :string
#  plan_id               :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  plan_name             :string
#
# Indexes
#
#  index_subscriptions_on_user_id  (user_id) UNIQUE
#

class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  attr_accessor :stripe_card_token
  attr_accessor :stripe_plan_id
  attr_accessor :trial_end

  validates_presence_of :stripe_customer_token, :message => 'Stripe Error'
  validates :plan, :presence => true
  validates :user, :uniqueness => true

  def save_with_stripe!(stripe_plan = (stripe_plan_id.present? ? stripe_plan_id : false ) || plan_id)
    # It has dynamic stripe plan variable if it exists either set
    # through controller or already on user or passed on call
    # which allows us to use it as upgrade as well.

    valid_params = (user.email && stripe_plan_id.present? && stripe_card_token.present?)

    if valid_params

      # Create customer and Set Card
      if trial_end.to_i == 0
        customer = Stripe::Customer.create(email: user.email, plan: stripe_plan_id, card: stripe_card_token)
      else
        customer = Stripe::Customer.create(email: user.email, plan: stripe_plan_id, card: stripe_card_token, trial_end: trial_end.to_i.days.from_now.to_time.to_i)
      end
      
      # customer.subscriptions.create(plan: stripe_plan)
      
      # Save Plan, Status and Customer Token
      self.update!(status: 'active', stripe_customer_token: customer.id)

    else

      return false

    end

  end

  def subscribe_with_stripe(options={})

    customer = Stripe::Customer.retrieve(stripe_customer_token)
    
    if options['trial_end'].to_i == 0
      sub = customer.subscriptions.create(plan: stripe_plan_id)
    else
      sub = customer.subscriptions.create(plan: stripe_plan_id, trial_end: options['trial_end'].to_i.days.from_now.to_time.to_i)
    end
    
    if sub[:status] == 'active'
      self.update(status: 'active', plan: Plan.find_by_name(stripe_plan_id))
    end

  end

  def unsubscribe_with_stripe
    customer = Stripe::Customer.retrieve(stripe_customer_token)
    sub_id = customer.subscriptions.data.find{|sub| sub[:plan][:id] == plan_id.to_s}[:id]
    delete = customer.subscriptions.retrieve(sub_id).delete
    if delete[:status] == 'canceled'
      self.update(status: 'canceled')
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
