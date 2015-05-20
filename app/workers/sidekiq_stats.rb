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
      Crawl.update_stats(crawl_id, processor_name)
      running_count = Crawl.running_count_for(crawl_id)
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
    puts 'start sidekiq and dyno stats'
    processor_name = options['processor_name']    
    puts 'scheduling sidekiq and dyno stats'
    SidekiqStats.perform_in(1.minute, options['crawl_id'], 'processor_name' => processor_name)
  end
  
end