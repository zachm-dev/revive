require 'namecheap' 

class Site < ActiveRecord::Base
  belongs_to :crawl
  has_many :pages
  has_many :links
  has_one :gather_links_batch
  has_many :process_links_batches
  
end
