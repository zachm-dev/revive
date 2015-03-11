require 'domainatrix'

class Link < ActiveRecord::Base
  belongs_to :site
  has_one :process_links_batch
  after_create :start_processing
  #after_create :create_process_links_batch
  
  private
  
  def create_process_links_batch
    ProcessLinksBatch.create(site_id: self.site_id, status: "pending", link_id: self.id)
    ProcessLinks.start(self.id)
  end
    
  def start_processing
    #link = Link.find(link_id)
    #links = link.links
    
    site = Site.using(:main_shard).find(site_id)
    crawl = site.crawl
    domain = Domainatrix.parse(site.base_url).domain
    
    if site.process_links_batch.nil?
      process_links_batch = Sidekiq::Batch.new
      site.update(processing_status: 'running')
      ProcessLinksBatch.using(:master).create(site_id: site.id, started_at: Time.now, status: "running", batch_id: process_links_batch.bid)
      process_links_batch.on(:complete, ProcessLinks, 'bid' => process_links_batch.bid)
      update(started: true)
    else
      process_links_batch = Sidekiq::Batch.new(site.process_links_batch.batch_id)
      update(started: true)
    end
    
    process_links_batch.jobs do
      links.each { |l| ProcessLinks.perform_async(l, site.id, found_on, domain) }
    end
    
  end
  
end
