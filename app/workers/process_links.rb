require 'domainatrix'

class ProcessLinks
  
  include Sidekiq::Worker
  sidekiq_options :queue => :process_links
  # sidekiq_options :retry => false
  
  def perform(l, site_id, found_on, domain)
    request = Typhoeus::Request.new(l, method: :head, followlocation: true)
    request.on_complete do |response|
      internal = l.include?("#{domain}") ? true : false
      if internal == true
        if "#{response.code}" == '404'
          Page.using(:main_shard).create(status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}")
        end
      elsif internal == false
        Page.using(:master).delay.create(status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}")
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
      
      site = Site.using(:main_shard).find(batch.site_id)
      crawl = site.crawl
      user = crawl.user
      user_id = user.id
      
      total_crawl_urls = Rails.cache.read(:total_crawl_urls).to_i
      total_site_urls = Link.where(site_id: site.id).sum(:links_count)
      # total_time = Time.now - batch.started_at
      # pages = Page.where(site_id: site.id).using(:master)
      # total_pages_crawled = pages.count
      # total_expired = site.total_expired.to_i + pages.where(internal: false, status_code: '0').count
      # total_broken = site.total_broken.to_i + pages.where(status_code: '404').count
      # crawl_total_pages_crawled = total_pages_crawled + crawl.total_pages_crawled.to_i
      # crawl_total_urls_found = total_site_urls + crawl.total_urls_found.to_i
      # pages_per_second = batch.link.site.pages.count / total_time
      # total_pages_processed = batch.link.site.pages.count
      # est_crawl_time = total_pages_processed / pages_per_second
      
      site.update(processing_status: 'finished', total_urls_found: total_site_urls)
      crawl.update(total_urls_found: total_crawl_urls)
      batch.update(finished_at: Time.now, status: "finished")
      # UserDashboard.update_crawl_stats(user.id, domains_broken: total_broken, domains_expired: total_expired, crawl_id: crawl.id)
      
      # if ProcessLinksBatch.where(status: 'running', crawl_id: crawl.id).count == 0
      #   puts "Finished ProcessLinks for crawl #{crawl.id} and shutting down server"
      #   crawl.update(status: 'finished')
      #   crawl.heroku_app.update(status: 'finished', finished_at: Time.now)
      #   Api.fetch_new_crawl(user_id: user_id)
      #   UserDashboard.add_finished_crawl(user.user_dashboard.id)
      #   if crawl.heroku_app.name.include?('revivecrawler')
      #     # heroku = HerokuPlatform.new
      #     # heroku.delete_app(crawl.heroku_app.name)
      #   end
      # end
    end
  end


  def self.start(link_id)
    link = Link.find(link_id)
    links = link.links
    site = Site.find(link.site_id)
    domain = Domainatrix.parse(site.base_url).domain
    batch = Sidekiq::Batch.new
    site.update(processing_status: 'running')
    link.process_links_batch.update(status: "running", started_at: Time.now, batch_id: batch.bid)
    batch.on(:complete, ProcessLinks, 'bid' => batch.bid)

    batch.jobs do
      links.each { |l| ProcessLinks.perform_async(l, site.id, link.found_on, domain) }
    end
  end

  
end