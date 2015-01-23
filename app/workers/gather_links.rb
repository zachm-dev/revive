class GatherLinks
  
  include Sidekiq::Worker
  
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
    Crawl.delay.decision_maker(user_id)
  end
  
  def self.start(site_id)
    site = Site.find(site_id)
    batch = Sidekiq::Batch.new
    site.gather_links_batch.update(status: "running", started_at: Time.now, batch_id: batch.bid)
    batch.on(:complete, self, 'bid' => batch.bid)
    batch.jobs do
      GatherLinks.perform_async(site_id)
    end
  end
  
  def self.sites(user_id, base_urls, options = {})
    
    name = options[:name]
    maxpages = options[:maxpages].empty? ? 10 : options[:maxpages].to_i
    new_crawl = Crawl.create(user_id: user_id, name: name, maxpages: maxpages)
    
    if base_urls.include?("\r\n")
      urls_array = base_urls.split(/[\r\n]+/).map(&:strip)
    else
      urls_array = base_urls.split(",")
    end
    
    urls_array.each do |u|
      new_site = new_crawl.sites.create(base_url: u.to_s, maxpages: maxpages)
      new_site.create_gather_links_batch(status: "pending")
      Crawl.delay.decision_maker(user_id)
    end
    
  end
  
end