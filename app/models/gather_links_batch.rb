# == Schema Information
#
# Table name: gather_links_batches
#
#  id                   :integer          not null, primary key
#  site_id              :integer
#  status               :string
#  started_at           :datetime
#  finished_at          :datetime
#  batch_id             :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  pages_per_second     :string
#  est_crawl_time       :string
#  total_links_gathered :string
#

class GatherLinksBatch < ActiveRecord::Base
  belongs_to :site
end
