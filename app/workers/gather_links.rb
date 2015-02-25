class GatherLinks
  
  include Sidekiq::Worker
  sidekiq_options retry: false
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
    puts "GatherLinks Just finished Batch #{options['bid']}"
    batch = GatherLinksBatch.where(batch_id: "#{options['bid']}").first
    if !batch.nil?
      user_id = batch.site.crawl.user.id
      crawl = batch.site.crawl
      total_urls_found = crawl.links.map(&:links).flatten.count
      crawl.update(total_urls_found: total_urls_found)
      total_time = Time.now - batch.started_at
      pages_per_second = batch.site.links.count / total_time
      total_links_gathered = batch.site.links.map(&:links).flatten.count
      est_crawl_time = total_links_gathered / pages_per_second
      batch.update(finished_at: Time.now, status: "finished", pages_per_second: "#{pages_per_second}", total_links_gathered: "#{total_links_gathered}", est_crawl_time: "#{est_crawl_time}")
      puts 'checking if there are more sites to crawl'
      GatherLinks.delay.start('crawl_id' => crawl.id)
    end
  end
  
  def self.start(options = {})
    
    if options["crawl_id"]
      running_crawl = Crawl.find(options["crawl_id"])
      gather_links_batch = running_crawl.gather_links_batches.where(status: 'pending').first
      if gather_links_batch
        site = gather_links_batch.site
      end
    else
      site = Site.where(id: options["site_id"]).first
    end
    
    if site
      gather_links_batch = Sidekiq::Batch.new
      site.gather_links_batch.update(status: "running", started_at: Time.now, batch_id: gather_links_batch.bid)
      gather_links_batch.on(:complete, self, 'bid' => gather_links_batch.bid)
      gather_links_batch.jobs do
        GatherLinks.perform_async(site.id)
      end
    end
  end
  
end