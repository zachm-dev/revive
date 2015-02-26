require 'domainatrix'

class ProcessLinks
  
  include Sidekiq::Worker
  sidekiq_options :queue => :process_links
  sidekiq_options retry: false
  
  def perform(l, site_id, found_on, domain)
    request = Typhoeus::Request.new(l, method: :head, followlocation: true)
    request.on_complete do |response|
      internal = l.include?("#{domain}") ? true : false
      if internal == true
        if "#{response.code}" == '404'
          Page.delay.create(status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}")
        end
      elsif internal == false
        Page.delay.create(status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}")
      end
    end
    begin
      request.run
    rescue
      nil
    end
  end
  
  def self.decision_maker(site_id)
    site = Site.find(site_id)
    user = site.crawl.user
    pending_count = user.process_links_batches.where(status: "pending").count
    running_count = user.process_links_batches.where(status: "running").count
    if pending_count > 0 #&& running_count < 1
      memory_stats = Heroku.memory_stats(type: 'processlinks')
      if memory_stats.include?("red")
        Heroku.scale_dyno(user_id: user.id, type: 'processlinks')
        puts "Scale dyno formation"
      else
        link_to_crawl_id = user.process_links_batches.where(status: "pending").first
        if !link_to_crawl_id.nil?
          ProcessLinks.start(link_to_crawl_id.link_id)
        end
      end
    end
  end
  
  def on_complete(status, options)
    batch = ProcessLinksBatch.where(batch_id: "#{options['bid']}").first
    if !batch.nil?
      user = batch.site.crawl.user
      user_id = user.id
      total_time = Time.now - batch.started_at
      crawl = batch.site.crawl
      total_pages_crawled = crawl.pages.uniq.count
      total_expired = crawl.pages.where(internal: false, status_code: '0').uniq.count
      total_broken = crawl.pages.where(status_code: '404').uniq.count
      crawl.update(total_pages_crawled: total_pages_crawled, total_expired: total_expired, total_broken: total_broken)
      UserDashboard.update_crawl_stats(user.id, domains_crawled: total_pages_crawled, domains_broken: total_broken, domains_expired: total_expired, crawl_id: crawl.id)
      #pages_per_second = batch.link.site.pages.count / total_time
      #total_pages_processed = batch.link.site.pages.count
      #est_crawl_time = total_pages_processed / pages_per_second
      batch.update(finished_at: Time.now, status: "finished")
      
      if batch.site.crawl.process_links_batches.where(status: 'running').count == 0
        puts "Finished ProcessLinks for crawl #{crawl.id} and shutting down server"
        batch.site.crawl.heroku_app.update(status: 'finished', finished_at: Time.now)
        Api.fetch_new_crawl(user_id: user_id)
        UserDashboard.add_finished_crawl(user.user_dashboard.id)
        # Crawl.decision_maker(user_id)
        if batch.site.crawl.heroku_app.name.include?('revivecrawler')
          heroku = Heroku.new
          heroku.delete_app(batch.site.crawl.heroku_app.name)
        end
      end
    end
  end


  def self.start(link_id)
    link = Link.find(link_id)
    links = link.links
    site = Site.find(link.site_id)
    #hydra = Typhoeus::Hydra.new
    domain = Domainatrix.parse(site.base_url).domain
    batch = Sidekiq::Batch.new
    link.process_links_batch.update(status: "running", started_at: Time.now, batch_id: batch.bid)
    batch.on(:complete, ProcessLinks, 'bid' => batch.bid)

    batch.jobs do
      links.each { |l| ProcessLinks.perform_async(l, site.id, link.found_on, domain) }
    end
  end
  
end