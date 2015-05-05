# == Schema Information
#
# Table name: plans
#
#  id                      :integer          not null, primary key
#  name                    :string
#  pages_per_crawl         :integer
#  expired_domains         :integer
#  broken_domains          :integer
#  crawls_at_the_same_time :integer
#  reserve_period          :integer
#  crawl_speed             :integer
#  marketplace             :boolean
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  price                   :float
#  crawls_per_day          :integer
#  crawls_per_hour         :integer
#  minutes_per_month       :float
#

class Plan < ActiveRecord::Base
  has_many :subscriptions
end
