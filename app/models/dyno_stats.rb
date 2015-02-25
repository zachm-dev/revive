class DynoStats
  
  # LIBRATO_EMAIL = ENV['librato_email']
  # LIBRATO_KEY = ENV['librato_key']
  
  def initialize(options={})
    app_name = options[:app_name].nil? ? Heroku::APP_NAME : options[:app_name]
    heroku = Heroku.client
    config_vars = heroku.config_var.info(app_name)
    librato_email = config_vars['LIBRATO_USER']
    librato_key = config_vars['LIBRATO_TOKEN']
    librato = Librato::Metrics.authenticate(librato_email, librato_key)
  end
  
  def metrics(options = {})
    metrics = Librato::Metrics.get_measurements "#{options[:metric]}".to_sym, :count => 1, source: "#{options[:source]}", resolution: 60
    puts "the metrics are #{metrics}"
    unless metrics.empty?
      return metrics["#{options[:source]}"][0]
    end
  end
  
  def self.last_checked?(options = {})
    puts "checking heroku app last update for site with id #{options[:site_id]}"
    if options[:site_id]
      site = Site.find(options[:site_id].to_i)
      heroku_app = site.crawl.heroku_app
      puts "dyno stats for app #{heroku_app.name}"
    end
    app_name = heroku_app.name
    heroku_app_last_update = heroku_app.updated_at
    
    if (Time.now - heroku_app_last_update) > 60
      puts 'more than a minute has passed since the dyno stats were checked'
      dynos = []
      ["processlinks", "worker"].each do |dyno|
        memory_stats = Heroku.memory_stats(type: dyno, app_name: app_name)
        if memory_stats.include?("red")
          dynos << dyno
        end
      end
      unless dynos.empty?
        puts 'checked app dyno stats and scaling dynos'
        Heroku.scale_dynos(app_name: app_name, dynos: dynos)
      end
      heroku_app.update(updated_at: Time.now)
    end
  end
  
end