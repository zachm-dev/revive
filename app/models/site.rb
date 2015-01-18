require 'namecheap' 

class Site < ActiveRecord::Base
  belongs_to :crawl
  has_many :pages
  has_many :links
  
end
