# == Schema Information
#
# Table name: expired_links
#
#  id           :integer          not null, primary key
#  url          :string
#  available    :string
#  site_i       :text
#  site_id      :integer
#  internal     :boolean
#  found_on     :text
#  simple_url   :text
#  citationflow :string
#  trustflow    :string
#  trustmetric  :string
#  refdomains   :string
#  backlinks    :string
#  pa           :string
#  da           :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class ExpiredLink < ActiveRecord::Base
end
