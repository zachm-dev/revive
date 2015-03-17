class ForkNewApp
  include Sidekiq::Worker
  
  def perform(heroku_app_id, number_of_apps_running)
    heroku_app = HerokuApp.find(heroku_app_id)
    heroku_app.update(name: "revivecrawler#{heroku_app.crawl.id}")
    HerokuPlatform.fork(HerokuPlatform::APP_NAME, "revivecrawler#{heroku_app.crawl.id}", heroku_app_id)
  end
  
  def on_complete(status, options)
    batch = HerokuApp.where(batch_id: "#{options['bid']}").first
    puts "heroku app is created with the following id #{options['bid']}"
    if !batch.nil?
      HerokuPlatform.migrate_db(batch.name)
      
      crawl = batch.crawl
      crawl.update(status: 'running')
      batch.update(status: "running")
      # UserDashboard.add_running_crawl(crawl.user.user_dashboard.id)
      Api.delay_for(1.minute).migrate_db(crawl_id: batch.crawl_id)
      Api.delay_for(2.minute).start_crawl(crawl_id: batch.crawl_id)
      # Api.delay.start_crawl(crawl_id: batch.crawl_id)
    end
  end
  
  def self.start(user_id, number_of_apps_running)
    crawl_to_start = HerokuApp.where(status: 'pending', user_id: user_id).order(:position).first
    
    batch = Sidekiq::Batch.new
    puts "heroku app bacth id is #{batch.bid}"
    crawl_to_start.update(status: "starting", started_at: Time.now, batch_id: batch.bid)
    batch.on(:complete, ForkNewApp, 'bid' => batch.bid)

    batch.jobs do
      ForkNewApp.perform_async(crawl_to_start.id, number_of_apps_running)
    end
  end
  
end