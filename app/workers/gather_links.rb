class GatherLinks
  
  include Sidekiq::Worker
  #sidekiq_options :queue => :gather_links
  
  def perform(site_id)
    site = Site.find(site_id)
    
    opts = {
      'maxpages' => site.maxpages
    }
    
    Retriever::PageIterator.new("#{site.base_url}", opts) do |page|
      Link.delay.create(site_id: site_id, links: page.links, found_on: "#{page.url}")
    end
  end
  
  def on_complete(status, options)
    batch = GatherLinksBatch.where(batch_id: "#{options['bid']}").first
    user_id = batch.site.crawl.user.id
    total_time = Time.now - batch.started_at
    pages_per_second = batch.site.links.count / total_time
    total_links_gathered = batch.site.links.map(&:links).flatten.count
    est_crawl_time = total_links_gathered / pages_per_second
    batch.update(finished_at: Time.now, status: "finished", pages_per_second: "#{pages_per_second}", total_links_gathered: "#{total_links_gathered}", est_crawl_time: "#{est_crawl_time}")
    puts "GatherLinks Just finished Batch #{options['bid']}"
    
    if batch.site.crawl.gather_links_batches.where(status: 'pending').count > 0
      Api.start_crawl(crawl_id: batch.site.crawl.id)
    end
  end
  
  def self.start(options = {})

    if options["crawl_id"]
      running_crawl = Crawl.find(options["crawl_id"])
      site = running_crawl.gather_links_batches.where(status: 'pending').first.site
    else
      site = Site.find(options["site_id"])
    end
    
    batch = Sidekiq::Batch.new
    site.gather_links_batch.update(status: "running", started_at: Time.now, batch_id: batch.bid)
    batch.on(:complete, self, 'bid' => batch.bid)
    batch.jobs do
      GatherLinks.perform_async(site.id)
    end
  end
  
end