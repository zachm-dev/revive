class Link < ActiveRecord::Base
  #serialize :links, Array
  belongs_to :site
end
