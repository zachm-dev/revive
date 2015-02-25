require 'platform-api'

class Heroku
  attr_accessor :api_token, :app_name, :log_url
  
  APP_NAME = ENV['heroku_app_name']
  API_TOKEN = ENV['heroku_api_token']

  def self.client
    @heroku ||= PlatformAPI.connect_oauth(API_TOKEN)
  end
  
  def client
    @heroku_client ||= PlatformAPI.connect_oauth(API_TOKEN)
  end
  
  def self.formation_info(options = {})
    formation_type = options[:type].nil? ? "worker" : options[:type] 
    app_name = options[:app_name].nil? ? APP_NAME : options[:app_name]
    heroku = self.client
    formation = heroku.formation.info(app_name, formation_type)
  end
  
  def self.app_list
    client.app.list
  end
  
  def self.formation_list(options = {})
    heroku = self.client
    app_name = options[:app_name].nil? ? APP_NAME : options[:app_name]
    formation = heroku.formation.list(app_name)
  end
  
  def self.get_dyno_stats(options = {})
    puts "dyno stats method"
    dyno_type = options[:type].nil? ? "worker" : options[:type] 
    app_name = options[:app_name].nil? ? APP_NAME : options[:app_name]
    formation = self.formation_info(type: dyno_type, app_name: options[:app_name])
    puts "here is the dyno formation"
    quantity = formation["quantity"]
    librato = DynoStats.new(app_name: app_name)
    stats = {}
    quantity.times do |index|
      puts "getting the dyno stats for #{dyno_type}.#{index+1}"
      memory_total = librato.metrics(metric: "memory_total", source: "#{dyno_type}.#{index+1}")
      resident_memory = librato.metrics(metric: "memory_rss", source: "#{dyno_type}.#{index+1}")
      swap_memory = librato.metrics(metric: "memory_swap", source: "#{dyno_type}.#{index+1}")
      stats["#{dyno_type}.#{index+1}"] = {memory_total: memory_total, resident_memory: resident_memory, swap_memory: swap_memory}
    end
    puts "the dyno stats for #{dyno_type} are #{stats}"
    stats
  end
  
  def self.memory_stats(options = {})
    dyno_type = options[:type].nil? ? "worker" : options[:type] 
    puts "here is the dyno type #{dyno_type}"
    app_name = options[:app_name].nil? ? APP_NAME : options[:app_name]
    puts "here is the app name #{app_name}"
    stats = self.get_dyno_stats(type: dyno_type, app_name: app_name)
    puts "here are the stats #{stats}"
    if !stats.empty?
      memory_stats = []
      stats.count.times do |index|
        memory_total = stats["#{dyno_type}.#{index+1}"][:memory_total]["value"]
        status = memory_total > 400 ? "red" : "green"
        memory_stats << status
      end
      puts "memory stats for #{dyno_type} are #{memory_stats}"
      return memory_stats
    end

  end
  
  def self.scale_dynos(options = {})
    puts 'scaling dynos'
    heroku = self.client
    dynos = options[:dynos].nil? ? ["worker"] : options[:dynos]
    app_name = options[:app_name].nil? ? APP_NAME : options[:app_name]
    increase_quantity = options[:quantity].nil? ? 1 : options[:quantity]
    size = options[:size].nil? ? '1X' : options[:size]
    
    dynos.each do |type|
      current_quantity = Heroku.formation_info(app_name: app_name, type: type)["quantity"]
      new_quantity = current_quantity + increase_quantity
      heroku.formation.update(app_name, type, {"quantity"=>new_quantity, 'size'=>size})
    end
    # if !options[:user_id].nil?
    #   Crawl.delay.decision_maker(options[:user_id])
    # end
  end
  
  def app_exists?(name)
    client.app.list.collect do |app|
      app if app['name'] == name
    end.reject(&:nil?).any?
  end
  
  def fork(from, to, heroku_app_id)
    app = HerokuApp.where(id: heroku_app_id).first
    if app && app.status != 'running'
      # check if there are any pending crawls before forking a new app from the user
      create_app(to)
      copy_slug(from, to)
      copy_config(from, to)
      add_redis(to)
      add_librato(to)
      copy_rack_and_rails_env_again(from, to)
      enable_log_runtime_metrics(to)
      Heroku.scale_dynos(app_name: to, quantity: 2, size: '1X', dynos: ["worker", "processlinks"])
      Heroku.scale_dynos(app_name: to, quantity: 1, size: '1X', dynos: ["sidekiqstats"])
      # restart_app(to)
      puts 'done creating new app'
    end
  end
  
  def release(app_name)
    client.release.list(app_name).last['slug']['id']
  end
  
  def delete_app(app_name)
    puts "deleting app #{app_name}"
    #logger.info "Deleting #{app_name}"
    client.app.delete(app_name)
  end
  
  def restart_app(app_name)
    puts 'restarting app'
    client.dyno.restart_all(app_name)
  end
  
  def add_redis(to)
    puts 'adding redis'
    client.addon.create(to, plan: "redistogo:smedium")
  end
  
  def add_librato(to)
    puts 'adding librato'
    client.addon.create(to, plan: "librato:nickel")
  end
  
  def enable_log_runtime_metrics(app_name)
    puts 'enabling log runtime metrics'
    client.app_feature.update(app_name, 'log-runtime-metrics', {'enabled'=>true})
  end
  
  def config_vars(app_name)
    client.config_var.info(app_name)
  end
  
  def create_app(name)
    # logger.info "Creating #{name}"
    puts 'creating app'
    client.app.create(name: name)
  end
  
  def copy_config(from, to)
    puts 'copying config'
    from_congig_vars = config_vars(from)
    from_congig_vars = from_congig_vars.except!('HEROKU_POSTGRESQL_BRONZE_URL', 'PGBACKUPS_URL', 'HEROKU_POSTGRESQL_COPPER_URL', 'PROXIMO_URL', 'LIBRATO_USER', 'LIBRATO_PASSWORD', 'LIBRATO_TOKEN', 'REDISTOGO_URL')
    client.config_var.update(to, from_congig_vars)
  end
  
  def copy_slug(from, to)
    puts 'copying slug'
    from_release_slug_id = release(from)
    client.release.create(to, slug: from_release_slug_id)
  end

  def copy_rack_and_rails_env_again(from, to)
    puts 'copying rack and rails env again'
    env_to_update = get_original_env(from)
    client.config_var.update(to, env_to_update) unless env_to_update.empty?
  end
  
  def get_original_env(from)
    environments = {}
    %w(RACK_ENV RAILS_ENV).each do |var|
      if client.config_var.info(from)[var]
        environments[var] = client.config_var.info(from)[var]
      end
    end
    environments
  end
  
end