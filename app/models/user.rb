# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string
#  password_digest        :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  first_name             :string
#  last_name              :string
#  phone                  :string
#  address_1              :string
#  address_2              :string
#  city                   :string
#  zip                    :string
#  state                  :string
#  country                :string
#  subscription_id        :integer
#  last_crawl             :datetime
#  crawls_this_hour       :integer
#  first_crawl            :datetime
#  minutes_used           :float
#  minutes_available      :float
#  auth_token             :string
#  password_reset_token   :string
#  password_reset_sent_at :datetime
#  admin                  :boolean          default(FALSE)
#
# Indexes
#
#  index_users_on_subscription_id  (subscription_id)
#

class User < ActiveRecord::Base
  has_secure_password

  has_one :user_dashboard
  has_one :subscription
  has_one :plan, through: :subscription
  has_many :crawls
  has_many :sites, through: :crawls
  has_many :pages, through: :sites
  has_many :gather_links_batches, through: :sites
  has_many :process_links_batches, through: :sites
  has_many :heroku_apps, through: :crawls

  validates_uniqueness_of :email
  validates :email, presence: true

  after_create :create_user_dashboard
  before_create { generate_token(:auth_token) }

  def self.admin_search(query)
    if query.present?
      where("email ilike :q", q: "%#{query}%")
    else
      all
    end
  end
  
  def send_password_reset
    generate_token(:password_reset_token)
    self.password_reset_sent_at = Time.zone.now
    save!
    UserMailer.password_reset(self).deliver
  end
  
  def generate_token(column)
    begin
      self[column] = SecureRandom.urlsafe_base64
    end while User.exists?(column => self[column])
  end

  def subscribed?
    subscription.present?
  end

end
