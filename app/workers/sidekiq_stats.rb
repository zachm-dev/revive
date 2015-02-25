class SidekiqStats
  
  include Sidekiq::Worker
  sidekiq_options :queue => :sidekiq_stats
  
  def perform(heroku_app_id)
    puts 'getting sidekiq stats'
    SidekiqStats.delay.start(heroku_app_id: heroku_app_id)
    stats = Sidekiq::Stats.new
    if stats.enqueued < 100
      app = HerokuApp.find(heroku_app_id)
 
      if app.sidekiq_stats.count == 0
        puts 'sidekiq stats did not exist creating it now'
        SidekiqStat.create(workers_size: stats.workers_size, enqueued: stats.enqueued, processed: stats.processed, heroku_app_id: heroku_app_id)
      else
        last_stats = app.sidekiq_stats.last
        if last_stats.try_count.nil?
          puts 'app has less than 100 in the queue'
          SidekiqStat.create(workers_size: stats.workers_size, enqueued: stats.enqueued, processed: stats.processed, try_count: 1, heroku_app_id: heroku_app_id)
        elsif last_stats.enqueued <= stats.enqueued && last_stats.try_count != 2
          if last_stats.try_count == 1
            puts 'app has less than 100 and seems to be stalling for the second time'
            SidekiqStat.create(workers_size: stats.workers_size, enqueued: stats.enqueued, processed: stats.processed, try_count: 2, heroku_app_id: heroku_app_id)
          else
            puts 'app has less than 100 but is still processing'
            SidekiqStat.create(workers_size: stats.workers_size, enqueued: stats.enqueued, processed: stats.processed, try_count: 1, heroku_app_id: heroku_app_id)
          end
        else
          puts 'app has stalled and shutting down'
          app.update(status: 'finished', finished_at: Time.now, shutdown: true)
          user = app.crawl.user
          UserDashboard.add_finished_crawl(user.user_dashboard.id)
          Crawl.decision_maker(user.id)
          heroku = Heroku.new
          heroku.delete_app(app.name)
        end
      end
      
    end
  end
  
  def self.start(options={})
    puts 'start sidekiq and dyno stats'
    
    if options["crawl_id"]
      crawl = Crawl.find(options["crawl_id"])
      heroku_app_id = crawl.heroku_app.id
    else
      heroku_app_id = options[:heroku_app_id].to_i
    end
    puts 'checking dyno stats'
    DynoStats.delay.last_checked?(heroku_app_id: heroku_app_id)
    puts 'scheduling sidekiq and dyno stats'
    SidekiqStats.perform_in(1.minute, heroku_app_id)
  end
  
end