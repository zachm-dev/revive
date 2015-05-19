class SidekiqStats
  
  include Sidekiq::Worker
  sidekiq_options :retry => false
  # sidekiq_options :queue => :sidekiq_stats
  
  def perform(crawl_id, options={})
    puts 'getting sidekiq stats'
    processor_name = options['processor_name']
    SidekiqStats.delay.start('crawl_id' => crawl_id, 'processor_name' => processor_name)
    Link.delay.start_processing
    VerifyNamecheap.delay(:queue => 'verify_domains').start
    puts 'SidekiqStats: called start processing from sidekiq stats'
    if !Rails.cache.read(['running_crawls']).empty? && Rails.cache.read(['running_crawls']).include?(crawl_id)
      
      crawl_urls_found = "crawl/#{crawl_id}/urls_found"
      crawl_expired_domains = "crawl/#{crawl_id}/expired_domains"
      crawl_broken_domains = "crawl/#{crawl_id}/broken_domains"
      stats = Rails.cache.read_multi(crawl_urls_found, crawl_expired_domains, crawl_broken_domains, raw: true)
      puts "SidekiqStats: updating crawl stats for crawl #{crawl_id}"
      Crawl.using("#{processor_name}").update(crawl_id, total_urls_found: stats[crawl_urls_found].to_i, total_broken: stats[crawl_broken_domains].to_i, total_expired: stats[crawl_expired_domains].to_i)
      
      processing_count = Rails.cache.read(["crawl/#{crawl_id}/processing_batches/ids"]).count
      expired_count = Rails.cache.read(["crawl/#{crawl_id}/expired_ids"]).count
      
      puts "the number of processing batches left are #{processing_count} and the number of expired domains left to be processed are #{expired_count} for the crawl #{crawl_id}"
      if processing_count <= 2 && expired_count <= 2
        puts "this crawl has finished all its jobs"
        puts "checking if other crawls are running to flush db"
        Rails.cache.read(['running_crawls']).to_a.count <= 1
        puts 'flushing redis'
        puts "updating crawl stats before finishing"
      end
      #
      # CHECK IF THE CRAWL HAS EXCEEDED THE AMOUNT OF MINUTES SPECIFIED
      #
    
      total_minutes_to_run = Rails.cache.read(["crawl/#{crawl_id}/total_minutes_to_run"], raw: true).to_i
      if total_minutes_to_run > 0
        total_minutes_running = ((Time.now - Rails.cache.read(["crawl/#{crawl_id}/start_time"], raw: true).to_time)/60).to_i
        if total_minutes_running > total_minutes_to_run
          puts 'shutting down crawl it has been running for longer than the time specified'
        
          app = HerokuApp.using("#{processor_name}").where(crawl_id: crawl_id).first
          app_name = app.name
          crawl = app.crawl
          
          puts 'updating crawl stats before shutting down'
          urls_found = "crawl/#{crawl.id}/urls_found"
          expired_domains = "crawl/#{crawl.id}/expired_domains"
          broken_domains = "crawl/#{crawl.id}/broken_domains"
          stats = Rails.cache.read_multi(urls_found, expired_domains, broken_domains, raw: true)
        
          crawl_total_time_in_minutes = (Time.now - Chronic.parse(Rails.cache.read(["crawl/#{crawl.id}/start_time"], raw: true))).to_f/60.to_f
          user = User.using(:main_shard).find(app.user_id)
          user.update(minutes_used: user.minutes_used.to_f+crawl_total_time_in_minutes)
        
          puts 'updating running crawls array'
          updated_running_crawls_array = Rails.cache.read(['running_crawls']).to_a - [crawl_id]
          Rails.cache.write(['running_crawls'], updated_running_crawls_array)
          
          puts 'shutting down the crawl model'
          Api.delay.stop_crawl('crawl_id' => crawl.id, 'processor_name' => processor_name)
          
          puts 'updating crawl stats to finished'
          Crawl.using("#{processor_name}").update(crawl.id, status: 'finished', total_urls_found: stats[urls_found].to_i, total_broken: stats[broken_domains].to_i, total_expired: stats[expired_domains].to_i, msg: 'app exceeded crawl minutes specified')

        end
      end
      
    end

  end
  
  
  
  def self.start(options={})
    puts 'start sidekiq and dyno stats'
    processor_name = options['processor_name']    
    
    # if options["crawl_id"]
    #   crawl = Crawl.using(:main_shard).find(options["crawl_id"])
    #   heroku_app_id = crawl.heroku_app.id
    # else
    #   heroku_app_id = options[:heroku_app_id].to_i
    # end
    
    # puts 'checking dyno stats'
    # DynoStats.delay.last_checked?(heroku_app_id: heroku_app_id)
    puts 'scheduling sidekiq and dyno stats'
    SidekiqStats.perform_in(1.minute, options['crawl_id'], 'processor_name' => processor_name)
  end
  
end