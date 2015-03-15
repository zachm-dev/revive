class GatherLinks
  
  include Sidekiq::Worker
  sidekiq_options retry: false
  # sidekiq_options :queue => :gather_links
  
  def perform(site_id, maxpages, base_url, max_pages_allowed, crawl_id)
    opts = {
      'maxpages' => maxpages
    }
    
    Retriever::PageIterator.new("#{base_url}", opts) do |page|
      total_crawl_urls = Rails.cache.read(:total_crawl_urls).to_i
      
      links = page.links
      links_count = links.count.to_i
      
      if total_crawl_urls < max_pages_allowed
        process = true
      else
        process = false
      end
      
      Link.using(:master).create(site_id: site_id, links: links, found_on: "#{page.url}", links_count: links_count, process: process, crawl_id: crawl_id)
      Rails.cache.increment("total_crawl_urls", links_count)
      Rails.cache.increment(["site/#{site_id}/total_site_urls"], links_count)
    end
  end
  
  def on_complete(status, options)
    puts "GatherLinks Just finished Batch #{options['bid']}"
    batch = GatherLinksBatch.where(batch_id: "#{options['bid']}").using(:main_shard).first
    if !batch.nil?
      
      total_crawl_urls = Rails.cache.read(:total_crawl_urls, raw: true).to_i
      puts "found gather links batch after complete for the site #{options['site_id']}"
      site = Site.using(:main_shard).find(options['site_id'])
      puts "here is the site id #{site.id}"
      crawl = site.crawl
      
      total_site_urls = Link.where(site_id: site.id).sum(:links_count)
      # total_time = Time.now - batch.started_at
      # pages_per_second = Link.where(site_id: site.id).count / total_time
      # est_crawl_time = total_urls_found / pages_per_second
      # crawl_total_urls = crawl.total_urls_found.to_i + total_urls_found
      
      crawl.update(total_urls_found: total_crawl_urls)
      site.update(total_urls_found: total_site_urls, gather_status: 'finished')
      batch.update(finished_at: Time.now, status: "finished")
      
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
        puts "the pending crawl is #{pending.id} on the site #{pending.site.id}"
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
      gather_links_batch.on(:complete, GatherLinks, 'bid' => gather_links_batch.bid, 'crawl_id' => options["crawl_id"], 'site_id' => site.id)
      gather_links_batch.jobs do
        puts 'starting to gather links'
        GatherLinks.perform_async(site.id, site.maxpages, site.base_url, running_crawl.max_pages_allowed, options["crawl_id"])
      end
    end
  end
  
end