# == Schema Information
#
# Table name: heroku_apps
#
#  id             :integer          not null, primary key
#  name           :string
#  url            :text
#  crawl_id       :integer
#  status         :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  started_at     :datetime
#  finished_at    :datetime
#  batch_id       :string
#  verified       :string
#  pos            :integer
#  position       :integer
#  shutdown       :boolean
#  librato_user   :string
#  librato_token  :string
#  formation      :hstore
#  db_url         :string
#  db_user        :string
#  db_pass        :string
#  db_host        :string
#  db_port        :integer
#  db_name        :string
#  user_id        :integer
#  processor_name :string
#

class HerokuApp < ActiveRecord::Base
  belongs_to :crawl
  has_many :sidekiq_stats
  acts_as_list
end
