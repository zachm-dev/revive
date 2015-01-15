class User < ActiveRecord::Base
  has_secure_password
  
  validates_uniqueness_of :email
  
  has_many :crawls
  has_many :sites, through: :crawls

end
