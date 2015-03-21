class GatherLinks
  
  include Sidekiq::Worker
  sidekiq_options retry: false
  # sidekiq_options :queue => :gather_links
  
  def perform(site_id, maxpages, base_url, max_pages_allowed, crawl_id)
    opts = {
      'maxpages' => maxpages
    }
    
    Retriever::PageIterator.new("#{base_url}", opts) do |page|
      total_crawl_urls = Rails.cache.read(["crawl/#{crawl_id}/urls_found"], raw: true).to_i
      
      links = page.links
      links_count = links.count.to_i
      
      Rails.cache.increment(["crawl/#{crawl_id}/urls_found"], links_count)
      Rails.cache.increment(["site/#{site_id}/total_site_urls"], links_count)
      
      if total_crawl_urls < max_pages_allowed
        process = true
      else
        process = false
      end
      
      Link.create(site_id: site_id, links: links, found_on: "#{page.url}", links_count: links_count, process: process, crawl_id: crawl_id)
    end
  end
  
  def on_complete(status, options)
    puts "GatherLinks Just finished Batch #{options['bid']}"
    batch = GatherLinksBatch.using(:processor).where(batch_id: "#{options['bid']}").first
    if !batch.nil?
      
      site = Site.using(:processor).find(options['site_id'])
      crawl = site.crawl
      
      total_crawl_urls = Rails.cache.read(["crawl/#{crawl.id}/urls_found"], raw: true).to_i
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
    
    puts 'gather links start method'
    running_crawl = Crawl.using(:processor).find(options["crawl_id"])
    
    if running_crawl.gather_links_batches.where(status: 'pending').count > 0
      pending = running_crawl.gather_links_batches.where(status: 'pending').first
      puts "the pending crawl is #{pending.id} on the site #{pending.site.id}"
      site = pending.site

      puts 'there is a site and gathering the links'
      gather_links_batch = Sidekiq::Batch.new
      site.update(gather_status: 'running')
      site.gather_links_batch.update(status: "running", started_at: Time.now, batch_id: gather_links_batch.bid)
      gather_links_batch.on(:complete, GatherLinks, 'bid' => gather_links_batch.bid, 'crawl_id' => options["crawl_id"], 'site_id' => site.id)
      gather_links_batch.jobs do
        puts 'starting to gather links'
        GatherLinks.perform_async(site.id, site.maxpages, site.base_url, running_crawl.max_pages_allowed, options["crawl_id"])
      end
      
    elsif running_crawl.crawl_type == 'keyword_crawl' && running_crawl.iteration.to_i < (Crawl::GOOGLE_PARAMS.count-1)
      
      new_iteration = (running_crawl.iteration.to_i+1)
      Crawl.using(:processor).update(running_crawl.id, iteration: new_iteration)
      SaveSitesFromGoogle.start_batch(options["crawl_id"], 'iteration' => new_iteration)
      
    end
    
  end
  
end