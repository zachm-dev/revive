# == Schema Information
#
# Table name: shard_infos
#
#  id             :integer          not null, primary key
#  crawl_id       :integer
#  processor_name :string
#  db_url         :string
#  user_id        :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  heroku_app_id  :integer
#

class ShardInfo < ActiveRecord::Base
end
