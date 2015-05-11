# == Schema Information
#
# Table name: sidekiq_stats
#
#  id            :integer          not null, primary key
#  workers_size  :integer
#  enqueued      :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  try_count     :integer
#  processed     :integer
#  heroku_app_id :integer
#

class SidekiqStat < ActiveRecord::Base
  belongs_to :heroku_app
end
