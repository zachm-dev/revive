require 'domainatrix'

class Link < ActiveRecord::Base
  belongs_to :site
  has_one :process_links_batch
  after_create :start_processing
  
  private
    
  def start_processing
    
    if process == true
      site = Site.using(:main_shard).find(site_id)
      crawl = site.crawl
      domain = Domainatrix.parse(site.base_url).domain
    
      if site.process_links_batch.nil?
        process_links_batch = Sidekiq::Batch.new
        site.update(processing_status: 'running')
        ProcessLinksBatch.using(:master).create(site_id: site.id, started_at: Time.now, status: "running", batch_id: process_links_batch.bid, crawl_id: crawl.id)
        process_links_batch.on(:complete, ProcessLinks, 'bid' => process_links_batch.bid)
      else
        process_links_batch = Sidekiq::Batch.new(site.process_links_batch.batch_id)
      end
    
      process_links_batch.jobs do
        links.each do |l|
          ProcessLinks.perform_async(l, site.id, found_on, domain)
        end
      end
    end
    
  end
  
end
