class HerokuApp < ActiveRecord::Base
  belongs_to :crawl
  acts_as_list
end
