require 'domainatrix'

class ProcessLinks
  
  include Sidekiq::Worker
  sidekiq_options :queue => :process_links
  # sidekiq_options :retry => false
  
  def perform(l, site_id, found_on, domain, crawl_id, options={})
    processor_name = options['processor_name']
    request = Typhoeus::Request.new(l, method: :head, followlocation: true, timeout: 15)
    request.on_complete do |response|
      
      # tt = Rails.cache.read(["crawl/#{crawl_id}/connections/total_time"], raw: true).to_f
      # ct = Rails.cache.read(["crawl/#{crawl_id}/connections/connect_time"], raw: true).to_f
      # Rails.cache.write(["crawl/#{crawl_id}/connections/total_time"], tt+response.total_time.to_f, raw: true)
      # Rails.cache.write(["crawl/#{crawl_id}/connections/connect_time"], ct+response.connect_time.to_f, raw: true)
      # Rails.cache.increment(["crawl/#{crawl_id}/connections/total"])
      
      internal = l.include?("#{domain}") ? true : false
      if internal == true && "#{response.code}" == '404'
        Page.using("#{processor_name}").create(status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}", crawl_id: crawl_id)
      elsif internal == false
        if "#{response.code}" == '404'
          Page.using("#{processor_name}").create(status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}", crawl_id: crawl_id)
        else
          # Page.using(:master).delay.create(status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}", crawl_id: crawl_id, processor_name: processor_name)
          
          redis_id = SecureRandom.hex+Time.now.to_i.to_s
          
          $redis.set(redis_id, {status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}", crawl_id: crawl_id, processor_name: processor_name}.to_json)
          Page.verify_namecheap('redis_id' => redis_id)
          
        end
      end
    end
    begin
      Timeout::timeout(10) do
        request.run
      end
    rescue Timeout::Error
      puts "slow response from #{l}"
    end
  end
  
  def on_complete(status, options={})
    puts "finished processing batch #{options}"
    
    processor_name = options['processor_name']
    
    total_site_count = Rails.cache.read(["site/#{options['site_id']}/processing_batches/total"], raw: true).to_i
    total_site_running = Rails.cache.decrement(["site/#{options['site_id']}/processing_batches/running"])
    total_site_finished = Rails.cache.increment(["site/#{options['site_id']}/processing_batches/finished"])

    total_crawl_count = Rails.cache.read(["crawl/#{options['crawl_id']}/processing_batches/total"], raw: true).to_i
    total_crawl_running = Rails.cache.decrement(["crawl/#{options['crawl_id']}/processing_batches/running"])
    total_crawl_finished = Rails.cache.increment(["crawl/#{options['crawl_id']}/processing_batches/finished"])
    
    progress = (total_crawl_finished.to_f/total_crawl_count.to_f)*100.to_f
    Rails.cache.write(["crawl/#{options['crawl_id']}/progress"], progress, raw: true)
    
    ids = Rails.cache.read(["crawl/#{options['crawl_id']}/processing_batches/ids"])
    Rails.cache.write(["crawl/#{options['crawl_id']}/processing_batches/ids"], ids-[options['link_id']])
    
    if total_crawl_running <= 0 && Sidekiq::Stats.new.workers_size == 0
      puts "shut down app and update crawl stats and user stats, crawl id #{options['crawl_id']}"
      
      puts "the sidekiq bofore shutting down crawl #{options['crawl_id']} are #{Sidekiq::Stats.new.instance_values}"
      
      puts "total_site_count, crawl id #{options['crawl_id']}: #{total_site_count}"
      puts "total_site_running, crawl id #{options['crawl_id']}: #{total_site_running}"
      puts "total_site_finished, crawl id #{options['crawl_id']}: #{total_site_finished}"
      
      puts "total_crawl_count, crawl id #{options['crawl_id']}: #{total_crawl_count}"
      puts "total_crawl_running, crawl id #{options['crawl_id']}: #{total_crawl_running}"
      puts "total_crawl_finished, crawl id #{options['crawl_id']}: #{total_crawl_finished}"
      
      puts "progress, crawl id #{options['crawl_id']}: #{progress}"
      
      
      app = HerokuApp.using("#{processor_name}").where(crawl_id: options['crawl_id']).first
      crawl = app.crawl
      
      if (options['crawl_type'] == 'keyword_crawl' && options['iteration'].to_i >= (Crawl::GOOGLE_PARAMS.count-1)) || options['crawl_type'] == "url_crawl"
        # SHUT DOWN APP
          if app.name.include?('revivecrawler')
        
            puts 'updating crawl stats before shutting down'
        
            crawl_urls_found = "crawl/#{options['crawl_id']}/urls_found"
            crawl_expired_domains = "crawl/#{options['crawl_id']}/expired_domains"
            crawl_broken_domains = "crawl/#{options['crawl_id']}/broken_domains"
        
            site_urls_found = "site/#{options['site_id']}/total_site_urls"
            site_expired_domains = "site/#{options['site_id']}/expired_domains"
            site_broken_domains = "site/#{options['site_id']}/broken_domains"
            
            

            stats = Rails.cache.read_multi(crawl_urls_found, crawl_expired_domains, crawl_broken_domains, site_urls_found, site_expired_domains, site_broken_domains, raw: true)
        
            Crawl.using("#{processor_name}").update(options['crawl_id'], status: 'finished', total_urls_found: stats[crawl_urls_found].to_i, total_broken: stats[crawl_broken_domains].to_i, total_expired: stats[crawl_expired_domains].to_i, msg: 'crawl finished all processing batches')
            crawl_total_time_in_minutes = (Time.now - Chronic.parse(Rails.cache.read(["crawl/#{options['crawl_id']}/start_time"], raw: true))).to_f/60.to_f
            user = User.using(:main_shard).find(app.user_id)
            user.update(minutes_used: user.minutes_used.to_f+crawl_total_time_in_minutes)
            
            UserDashboard.update_crawl_stats(options['user_id'], 
                                            'domains_broken' => stats[crawl_broken_domains], 
                                            'domains_expired' => stats[crawl_expired_domains],
                                            'domains_crawled' => stats[crawl_urls_found],
                                            'finished_crawls' => 1,
                                            'running_crawls' => -1
                                            )
        
            puts 'shutting it down: the crawl is finished'
        
            heroku = HerokuPlatform.new
            heroku.delete_app(app.name)
          end
        # SHUT DOWN APP
      end

    elsif total_site_running <= 0
      
      puts 'updating site stats'
      
      crawl_urls_found = "crawl/#{options['crawl_id']}/urls_found"
      crawl_expired_domains = "crawl/#{options['crawl_id']}/expired_domains"
      crawl_broken_domains = "crawl/#{options['crawl_id']}/broken_domains"
      
      site_urls_found = "site/#{options['site_id']}/total_site_urls"
      site_expired_domains = "site/#{options['site_id']}/expired_domains"
      site_broken_domains = "site/#{options['site_id']}/broken_domains"
      
      stats = Rails.cache.read_multi(crawl_urls_found, crawl_expired_domains, crawl_broken_domains, site_urls_found, site_expired_domains, site_broken_domains, raw: true)
      
      Site.using("#{processor_name}").update(options['site_id'], processing_status: 'finished', total_urls_found: stats[site_urls_found].to_i, total_expired: stats[site_expired_domains].to_i, total_broken: stats[site_broken_domains].to_i)
      Crawl.using("#{processor_name}").update(options['crawl_id'], total_urls_found: stats[crawl_urls_found].to_i, total_broken: stats[crawl_broken_domains].to_i, total_expired: stats[crawl_expired_domains].to_i)
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