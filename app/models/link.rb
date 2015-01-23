class Link < ActiveRecord::Base
  belongs_to :site
  has_one :process_links_batch
  after_create :create_process_links_batch
  
  private
  
  def create_process_links_batch
    ProcessLinksBatch.create(site_id: self.site_id, status: "pending", link_id: self.id)
    ProcessLinks.start(self.id)
  end
    
  def start_processing
    ProcessLinks.start(self.id)
  end
  
end
