class User < ActiveRecord::Base
  after_create :create_user_dashboard

  has_secure_password

  validates_uniqueness_of :email

  has_one :user_dashboard
  has_one :subscription
  has_many :crawls
  has_many :sites, through: :crawls
  has_many :pages, through: :sites
  has_many :gather_links_batches, through: :sites
  has_many :process_links_batches, through: :sites
  has_many :heroku_apps, through: :crawls

  def subscribed?
    subscription.present?
  end

end
