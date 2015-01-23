class User < ActiveRecord::Base
  has_secure_password
  
  validates_uniqueness_of :email
  
  has_many :crawls
  has_many :sites, through: :crawls
  has_many :gather_links_batches, through: :sites

end
