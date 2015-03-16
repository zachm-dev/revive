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
  
  def on_complete(status, options={})
    puts "finished processing batch #{options}"
    
    total_site_count = Rails.cache.read(["site/#{options['site_id']}/processing_batches/total"], raw: true).to_i
    total_site_running = Rails.cache.decrement(["site/#{options['site_id']}/processing_batches/running"])
    total_site_finished = Rails.cache.increment(["site/#{options['site_id']}/processing_batches/finished"])

    total_crawl_count = Rails.cache.read(["crawl/#{options['crawl_id']}/processing_batches/total"], raw: true).to_i
    total_crawl_running = Rails.cache.decrement(["crawl/#{options['crawl_id']}/processing_batches/running"])
    total_crawl_finished = Rails.cache.increment(["crawl/#{options['crawl_id']}/processing_batches/finished"])

    total_crawl_urls = Rails.cache.read(["crawl/#{options['crawl_id']}/urls_found"], raw: true).to_i
    total_site_urls = Rails.cache.read(["site/#{options['site_id']}/total_site_urls"], raw: true).to_i
    progress = (total_crawl_finished.to_f/total_crawl_count.to_f)*100.to_f
    Rails.cache.write(["crawl/#{options['crawl_id']}/progress"], progress, raw: true)
    
    ids = Rails.cache.read(["crawl/#{options['crawl_id']}/processing_batches/ids"])
    Rails.cache.write(["crawl/#{options['crawl_id']}/processing_batches/ids"], ids-[options['link_id']])
    
    if total_crawl_count == total_crawl_finished
      puts 'shut down app and update crawl stats and user stats'
      app = HerokuApp.where(crawl_id: options['crawl_id']).using(:main_shard).first
      if app.name.include?('revivecrawler')
        heroku = HerokuPlatform.new
        heroku.delete_app(app.name)
      end
    elsif total_site_count == total_site_finished
      Site.using(:main_shard).update(options['site_id'], processing_status: 'finished', total_urls_found: total_site_urls)
      Crawl.using(:main_shard).update(options['crawl_id'], total_urls_found: total_crawl_urls)
    else
      puts 'do something else'
    end

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
    

    # batch.update(finished_at: Time.now, status: "finished")
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