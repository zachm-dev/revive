# == Schema Information
#
# Table name: verify_majestic_batches
#
#  id          :integer          not null, primary key
#  site_id     :integer
#  started_at  :datetime
#  finished_at :datetime
#  batch_id    :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class VerifyMajesticBatch < ActiveRecord::Base
  belongs_to :site
end
