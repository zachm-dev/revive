# == Schema Information
#
# Table name: process_links_batches
#
#  id               :integer          not null, primary key
#  site_id          :integer
#  status           :string
#  started_at       :datetime
#  finished_at      :datetime
#  batch_id         :string
#  pages_per_second :string
#  est_crawl_time   :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  link_id          :integer
#  crawl_id         :integer
#

class ProcessLinksBatch < ActiveRecord::Base
  #belongs_to :link
  belongs_to :site
end
