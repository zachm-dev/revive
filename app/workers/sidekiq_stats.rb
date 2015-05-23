class SidekiqStats
  
  include Sidekiq::Worker
  sidekiq_options :retry => 3
  # sidekiq_options :queue => :sidekiq_stats
  
  def perform(crawl_id, options={})
    puts 'getting sidekiq stats'
    if Rails.cache.read(['running_crawls']).include?(crawl_id)
      processor_name = options['processor_name']
      
      if Sidekiq::ScheduledSet.new.size.to_i < 10
        SidekiqStats.delay.start('crawl_id' => crawl_id, 'processor_name' => processor_name)
      end
      
      running_count = Crawl.running_count_for(crawl_id)
      
      if running_count['processing_count'].to_i > 1
        puts 'SidekiqStats: called start processing from sidekiq stats'
        Link.delay(:queue => 'process_links').start_processing
      end
      
      if running_count['expired_count'].to_i > 1
        VerifyNamecheap.delay(:queue => 'verify_domains').start
      end

      Crawl.update_stats(crawl_id, processor_name)
      $redis.del($redis.smembers("finished_processing/#{crawl_id}"))
      
      puts "the number of processing batches left are #{running_count['processing_count']} and the number of expired domains left to be processed are #{running_count['expired_count']} for the crawl #{crawl_id}"
      if running_count['processing_count'].to_i <= 2 && running_count['expired_count'].to_i <= 2
        puts "this crawl has finished all its jobs"
        Api.delay.stop_crawl('crawl_id' => crawl_id, 'processor_name' => processor_name)
      end
      total_minutes_to_run = Rails.cache.read(["crawl/#{crawl_id}/total_minutes_to_run"], raw: true).to_i
      if total_minutes_to_run > 0
        total_minutes_running = ((Time.now - Rails.cache.read(["crawl/#{crawl_id}/start_time"], raw: true).to_time)/60).to_i
        if total_minutes_running > total_minutes_to_run
          puts 'shutting down crawl it has been running for longer than the time specified'
          Api.delay.stop_crawl('crawl_id' => crawl_id, 'processor_name' => processor_name)
        end
      end
    end
  end
  
  def self.start(options={})
    if Rails.cache.read(['running_crawls']).include?(options['crawl_id'])
      if Sidekiq::Queue.new.select{|j|j.args[0].to_s.include?('SidekiqStats')}.count < 10
        puts 'start sidekiq and dyno stats'
        processor_name = options['processor_name']    
        puts 'scheduling sidekiq and dyno stats'
        if Sidekiq::ScheduledSet.new.size.to_i < 10
          SidekiqStats.perform_in(1.minute, options['crawl_id'], 'processor_name' => processor_name)
        end
      end
    end
  end
  
end