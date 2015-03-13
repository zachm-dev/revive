class GatherLinks
  
  include Sidekiq::Worker
  sidekiq_options retry: false
  #sidekiq_options :queue => :gather_links
  
  def perform(site_id)
    site = Site.using(:main_shard).find(site_id)
    
    opts = {
      'maxpages' => site.maxpages
    }
    
    Retriever::PageIterator.new("#{site.base_url}", opts) do |page|
      links = page.links
      Link.using(:master).create(site_id: site_id, links: links, found_on: "#{page.url}", links_count: links.count.to_i)
    end
  end
  
  def on_complete(status, options)
    puts "GatherLinks Just finished Batch #{options['bid']}"
    batch = GatherLinksBatch.where(batch_id: "#{options['bid']}").using(:main_shard).first
    if !batch.nil?
      puts "found gather links batch after complete"
      site = Site.using(:main_shard).find(batch.site_id)
      puts "here is the site id #{site.id} and object #{site}"
      crawl = site.crawl
      user_id = crawl.user.id
      total_urls_found = Link.where(site_id: site.id).map(&:links).flatten.count
      total_time = Time.now - batch.started_at
      pages_per_second = Link.where(site_id: site.id).count / total_time
      est_crawl_time = total_urls_found / pages_per_second
      crawl_total_urls = crawl.total_urls_found.to_i + total_urls_found
      # crawl.update(total_urls_found: crawl_total_urls)
      # site.update(total_urls_found: total_urls_found, gather_status: 'finished')
      # batch.update(finished_at: Time.now, status: "finished", pages_per_second: "#{pages_per_second}", est_crawl_time: "#{est_crawl_time}")
      puts "checking if there are more sites to crawl #{crawl.id}"
      GatherLinks.delay.start('crawl_id' => crawl.id)
    end
  end
  
  def self.start(options = {})
    if options["crawl_id"]
      puts 'gather links start method'
      running_crawl = Crawl.using(:main_shard).find(options["crawl_id"])
      pending = running_crawl.gather_links_batches.where(status: 'pending').first
      if pending
        puts "the pending crawl is #{pending} on the site #{pending.site}"
        site = pending.site
      end
    else
      site = Site.using(:main_shard).where(id: options["site_id"]).first
    end
    
    if site
      puts 'there is a site and gathering the links'
      gather_links_batch = Sidekiq::Batch.new
      site.update(gather_status: 'running')
      site.gather_links_batch.update(status: "running", started_at: Time.now, batch_id: gather_links_batch.bid)
      gather_links_batch.on(:complete, GatherLinks, 'bid' => gather_links_batch.bid)
      gather_links_batch.jobs do
        puts 'starting to gather links'
        GatherLinks.perform_async(site.id)
      end
    end
  end
  
end