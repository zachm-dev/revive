class SidekiqStats
  
  include Sidekiq::Worker
  # sidekiq_options :queue => :sidekiq_stats
  
  def perform(crawl_id)
    puts 'getting sidekiq stats'
    
    SidekiqStats.delay.start('crawl_id' => crawl_id)
    
    if Sidekiq::Stats.new.enqueued < 100
      
      current_stats = Rails.cache.read(["crawl/#{crawl_id}/processing_batches/running"], raw: true).to_i
      
      if current_stats != 0
        last_checked_time = Rails.cache.read(["stats/#{crawl_id}/last_checked_stats/time"])
      
        if !last_checked_time.nil?
        
          last_checked_stats = Rails.cache.read(["stats/#{crawl_id}/last_checked_stats/running"], raw: true).to_i
          time_diff = (Time.now - Rails.cache.read(["stats/#{crawl_id}/last_checked_stats/time"]).to_time)
        
          if time_diff > 60
            if last_checked_stats == current_stats
              stats_verify_count = Rails.cache.read(["stats/#{crawl_id}/verify_count"], raw: true).to_i
              if stats_verify_count == 0
                puts 'stats have been the same for the past minute: increasing verify count'
                Rails.cache.increment(["stats/#{crawl_id}/verify_count"])
              elsif stats_verify_count == 1
                puts 'stats have been the same for the past two minutes: restarting app: increasing verify count'
                Rails.cache.increment(["stats/#{crawl_id}/verify_count"])
              
                app = HerokuApp.using(:processor).where(crawl_id: crawl_id).first
                app_name = app.name
              
                heroku = HerokuPlatform.new
                heroku.restart_app(app_name)
              elsif stats_verify_count == 2
                puts 'stats have been the same for the past three minutes: increasing verify count'
                Rails.cache.increment(["stats/#{crawl_id}/verify_count"])
              elsif stats_verify_count >= 3
                puts 'app has stalled shutting it down'
                app = HerokuApp.using(:processor).where(crawl_id: crawl_id).first
                app_name = app.name
                crawl = app.crawl
              
                puts 'updating crawl stats before shutting down'
                urls_found = "crawl/#{crawl.id}/urls_found"
                expired_domains = "crawl/#{crawl.id}/expired_domains"
                broken_domains = "crawl/#{crawl.id}/broken_domains"
                stats = Rails.cache.read_multi(urls_found, expired_domains, broken_domains, raw: true)
                Crawl.using(:processor).update(crawl.id, status: 'finished', total_urls_found: stats[urls_found].to_i, total_broken: stats[broken_domains].to_i, total_expired: stats[expired_domains].to_i, msg: 'app stalled')
              
                heroku = HerokuPlatform.new
                heroku.delete_app(app_name)
              end
            else
              puts 'resetting verify count back to 0'
              Rails.cache.write(["stats/#{crawl_id}/verify_count"], 0, raw: true)
            end
            Rails.cache.write(["stats/#{crawl_id}/last_checked_stats/running"], current_stats, raw: true).to_i
          end
      
        end
        Rails.cache.write(["stats/#{crawl_id}/last_checked_stats/time"], "#{Time.now}")
      end
      
    end

    # stats = Sidekiq::Stats.new
    # if stats.enqueued < 100
    #   sidekiq_stats = SidekiqStat.where(heroku_app_id: heroku_app_id)
    #
    #   if sidekiq_stats.count == 0
    #     puts 'sidekiq stats did not exist creating it now'
    #     SidekiqStat.create(workers_size: stats.workers_size, enqueued: stats.enqueued, processed: stats.processed, heroku_app_id: heroku_app_id)
    #   else
    #     last_stats = sidekiq_stats.last
    #     if last_stats.try_count.nil?
    #       puts 'app has less than 100 in the queue'
    #       SidekiqStat.create(workers_size: stats.workers_size, enqueued: stats.enqueued, processed: stats.processed, try_count: 1, heroku_app_id: heroku_app_id)
    #     elsif last_stats.enqueued <= stats.enqueued && last_stats.try_count != 2
    #       if last_stats.try_count == 1
    #         puts 'app has less than 100 and seems to be stalling for the second time'
    #         SidekiqStat.create(workers_size: stats.workers_size, enqueued: stats.enqueued, processed: stats.processed, try_count: 2, heroku_app_id: heroku_app_id)
    #       else
    #         puts 'app has less than 100 but is still processing'
    #         SidekiqStat.create(workers_size: stats.workers_size, enqueued: stats.enqueued, processed: stats.processed, try_count: 1, heroku_app_id: heroku_app_id)
    #       end
    #     else
    #       puts 'app has stalled and shutting down'
    #       # crawl = app.crawl
    #       # crawl.update(status: 'finished')
    #       # app.update(status: 'finished', finished_at: Time.now, shutdown: true)
    #       # user = crawl.user
    #       # Api.fetch_new_crawl(user_id: user.id)
    #       # UserDashboard.add_finished_crawl(user.user_dashboard.id)
    #       # # Crawl.decision_maker(user.id)
    #       # if app.name.include?('revivecrawler')
    #       #   heroku = Heroku.new
    #       #   heroku.delete_app(app.name)
    #       # end
    #     end
    #   end
    #
    # end
  end
  
  def self.start(options={})
    puts 'start sidekiq and dyno stats'
    
    # if options["crawl_id"]
    #   crawl = Crawl.using(:main_shard).find(options["crawl_id"])
    #   heroku_app_id = crawl.heroku_app.id
    # else
    #   heroku_app_id = options[:heroku_app_id].to_i
    # end
    
    # puts 'checking dyno stats'
    # DynoStats.delay.last_checked?(heroku_app_id: heroku_app_id)
    puts 'scheduling sidekiq and dyno stats'
    SidekiqStats.perform_in(1.minute, options['crawl_id'])
  end
  
end