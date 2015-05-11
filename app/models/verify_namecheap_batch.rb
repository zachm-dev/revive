# == Schema Information
#
# Table name: verify_namecheap_batches
#
#  id          :integer          not null, primary key
#  page_id     :integer
#  batch_id    :string
#  status      :string
#  started_at  :datetime
#  finished_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  site_id     :integer
#

class VerifyNamecheapBatch < ActiveRecord::Base
  belongs_to :site
end
