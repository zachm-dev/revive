class ForkNewApp
  include Sidekiq::Worker
  
  def perform(heroku_app_id)
    heroku_app = HerokuApp.find(heroku_app_id)
    heroku = Heroku.new
    number_of_apps_running = Heroku.app_list.count
    heroku_app.update(name: "revivecrawler#{number_of_apps_running+1}")
    heroku.fork(Heroku::APP_NAME, "revivecrawler#{number_of_apps_running+1}")
  end
  
  def on_complete(status, options)
    batch = HerokuApp.where(batch_id: "#{options['bid']}").first
    puts "heroku app is created with the following id #{options['bid']}"
    if !batch.nil?
      batch.update(status: "running")
      UserDashboard.add_running_crawl(batch.crawl.user.user_dashboard.id)
      Api.delay.start_crawl(crawl_id: batch.crawl_id)
    end
  end
  
  def self.start(user_id)
    user = User.find(user_id)
    crawl_to_start = user.heroku_apps.where(status: 'pending').order(:position).first
    
    batch = Sidekiq::Batch.new
    puts "heroku app bacth id is #{batch.bid}"
    crawl_to_start.update(status: "starting", started_at: Time.now, batch_id: batch.bid)
    batch.on(:complete, ForkNewApp, 'bid' => batch.bid)

    batch.jobs do
      ForkNewApp.perform_async(crawl_to_start.id)
    end
  end
  
end