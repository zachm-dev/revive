require 'domainatrix'

class ProcessLinks
  
  include Sidekiq::Worker
  sidekiq_options :queue => :process_links
  sidekiq_options :retry => false
  
  def perform(l, site_id, found_on, domain)
    
    crawl = Site.find(site_id).crawl
    
    # if crawl.notify_me_after.is_a?(Integer) && crawl.notified == false
    #   if crawl.links.where(started: true).sum(:links_count).to_i >= site.crawl.notify_me_after
    #     NotifyMailer.notify(crawl.id).deliver
    #   end
    # end
    request = Typhoeus::Request.new(l, method: :head, followlocation: true)
    request.on_complete do |response|
      internal = l.include?("#{domain}") ? true : false
      if internal == true
        if "#{response.code}" == '404'
          Page.create(status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}")
        end
      elsif internal == false
        Page.create(status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}")
      end
    end
    begin
      request.run
    rescue
      nil
    end
  end
  
  def on_complete(status, options)
    batch = ProcessLinksBatch.where(batch_id: "#{options['bid']}").first
    if !batch.nil?
      site = batch.site
      crawl = site.crawl
      user = crawl.user
      user_id = user.id
      total_time = Time.now - batch.started_at
      total_pages_crawled = site.pages.count
      total_site_urls = site.links.map(&:links).flatten.count
      total_expired = site.total_expired.to_i + site.pages.where(internal: false, status_code: '0').count
      total_broken = site.total_broken.to_i + site.pages.where(status_code: '404').count
      crawl_total_pages_crawled = total_pages_crawled + crawl.total_pages_crawled.to_i
      crawl_total_urls_found = total_site_urls + crawl.total_urls_found.to_i
      site.update(total_pages_crawled: total_pages_crawled, processing_status: 'finished', total_urls_found: total_site_urls)
      UserDashboard.update_crawl_stats(user.id, domains_crawled: total_pages_crawled, domains_broken: total_broken, domains_expired: total_expired, crawl_id: crawl.id)
      #pages_per_second = batch.link.site.pages.count / total_time
      #total_pages_processed = batch.link.site.pages.count
      #est_crawl_time = total_pages_processed / pages_per_second
      crawl.update(total_urls_found: crawl_total_urls_found, total_pages_crawled: crawl_total_pages_crawled)
      batch.update(finished_at: Time.now, status: "finished")
      
      if crawl.process_links_batches.where(status: 'running').count == 0
        puts "Finished ProcessLinks for crawl #{crawl.id} and shutting down server"
        crawl.update(status: 'finished')
        crawl.heroku_app.update(status: 'finished', finished_at: Time.now)
        Api.fetch_new_crawl(user_id: user_id)
        UserDashboard.add_finished_crawl(user.user_dashboard.id)
        if crawl.heroku_app.name.include?('revivecrawler')
          heroku = Heroku.new
          heroku.delete_app(crawl.heroku_app.name)
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
    site.update(processing_status: 'running')
    link.process_links_batch.update(status: "running", started_at: Time.now, batch_id: batch.bid)
    batch.on(:complete, ProcessLinks, 'bid' => batch.bid)

    batch.jobs do
      links.each { |l| ProcessLinks.perform_async(l, site.id, link.found_on, domain) }
    end
  end
  
  # def self.decision_maker(site_id)
  #   site = Site.find(site_id)
  #   user = site.crawl.user
  #   pending_count = user.process_links_batches.where(status: "pending").count
  #   running_count = user.process_links_batches.where(status: "running").count
  #   if pending_count > 0 #&& running_count < 1
  #     memory_stats = Heroku.memory_stats(type: 'processlinks')
  #     if memory_stats.include?("red")
  #       Heroku.scale_dyno(user_id: user.id, type: 'processlinks')
  #       puts "Scale dyno formation"
  #     else
  #       link_to_crawl_id = user.process_links_batches.where(status: "pending").first
  #       if !link_to_crawl_id.nil?
  #         ProcessLinks.start(link_to_crawl_id.link_id)
  #       end
  #     end
  #   end
  # end
  
end