require 'platform-api'

class HerokuPlatform
  attr_accessor :api_token, :app_name, :log_url
  
  APP_NAME = ENV['heroku_app_name']
  API_TOKEN = ENV['heroku_api_token']

  def initialize
    @heroku ||= PlatformAPI.connect_oauth(API_TOKEN)
  end
  
  def formation_info(options = {})
    formation_type = options[:type].nil? ? "worker" : options[:type] 
    app_name = options[:app_name].nil? ? APP_NAME : options[:app_name]
    formation = @heroku.formation.info(app_name, formation_type)
  end
  
  def app_list
    @heroku.app.list
  end
  
  def formation_list(options = {})
    app_name = options[:app_name].nil? ? APP_NAME : options[:app_name]
    formation = @heroku.formation.list(app_name)
  end
  
  def self.get_dyno_stats(options = {})
    puts "dyno stats method"
    dyno_type = options[:type].nil? ? "worker" : options[:type] 
    app_name = options[:app_name].nil? ? APP_NAME : options[:app_name]
    app = HerokuApp.find(options[:heroku_app_id])
    # formation = self.formation_info(type: dyno_type, app_name: options[:app_name])
    quantity = app.formation[dyno_type]
    # puts "here is the dyno formation #{formation}"
    # quantity = formation["quantity"]
    librato = DynoStats.new(heroku_app_id: options[:heroku_app_id])
    stats = {}
    quantity.to_i.times do |index|
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
    stats = self.get_dyno_stats(type: dyno_type, app_name: app_name, heroku_app_id: options[:heroku_app_id])
    puts "here are the stats #{stats}"
    if !stats.empty?
      memory_stats = []
      stats.count.times do |index|
        memory_total = stats["#{dyno_type}.#{index+1}"][:memory_total]["value"]
        status = memory_total > 350 ? "red" : "green"
        memory_stats << status
      end
      puts "memory stats for #{dyno_type} are #{memory_stats}"
      return memory_stats
    end
  end
  
  def scale_dynos(options = {})
    puts 'scaling dynos'
    dynos = options[:dynos].nil? ? ["worker"] : options[:dynos]
    app_name = options[:app_name].nil? ? APP_NAME : options[:app_name]
    increase_quantity = options[:quantity].nil? ? 1 : options[:quantity]
    size = options[:size].nil? ? '1X' : options[:size]
    app = options[:heroku_app_id].nil? ? nil : HerokuApp.find(options[:heroku_app_id])
    dynos.each do |type|
      
      if app
        current_quantity = app.formation[type].to_i
        new_quantity = current_quantity + increase_quantity
        @heroku.formation.update(app_name, type, {"quantity"=>new_quantity, 'size'=>size})
        app.formation[type] = new_quantity
        app.save
      else
        current_quantity = formation_info(app_name: app_name, type: type)["quantity"]
        new_quantity = current_quantity + increase_quantity
        @heroku.formation.update(app_name, type, {"quantity"=>new_quantity, 'size'=>size})
      end

    end
  end
  
  def start_dynos(app_name, quantity, size, dynos)
    puts 'starting dynos'
    dynos.each do |type|
      @heroku.formation.update(app_name, type, {"quantity"=>quantity, 'size'=>size})
    end
  end
  
  def app_exists?(name)
    @heroku.app.list.collect do |app|
      app if app['name'] == name
    end.reject(&:nil?).any?
  end
  
  def self.fork(from, to, heroku_app_id)
    app = HerokuApp.where(id: heroku_app_id).first
    if app && app.status != 'running'
      heroku = HerokuPlatform.new
      # check if there are any pending crawls before forking a new app from the user
      heroku.create_app(to)
      sleep 10
      heroku.check_and_copy_slug(from, to)
      sleep 10
      heroku.copy_config(from, to)
      sleep 10
      heroku.upgrade_postgres(to)
      sleep 10
      heroku.add_redis(to)
      sleep 10
      heroku.add_librato(to)
      sleep 5
      heroku.copy_rack_and_rails_env_again(from, to)
      sleep 5
      heroku.enable_log_runtime_metrics(to)
      sleep 5
      librato_env_vars = heroku.get_librato_env_variables_for(to)
      heroku.start_dynos(to, 3, '2X', ["processlinks"])
      sleep 5
      heroku.start_dynos(to, 2, '1X', ["worker", "verifydomains"])
      sleep 5
      # heroku.scale_dynos(app_name: to, quantity: 1, size: '1X', dynos: ["verifydomains"])
      # heroku.scale_dynos(app_name: to, quantity: 1, size: '1X', dynos: ["sidekiqstats"])
      app.update(librato_user: librato_env_vars[:librato_user], librato_token: librato_env_vars[:librato_token], formation: {worker: 2, processlinks: 2, sidekiqstats: 1})
      Crawl.using(:main_shard).update(app.crawl.id, redis_url: librato_env_vars[:redis_url])
      # restart_app(to)
      puts 'done creating new app'
    end
  end
  
  def rate_limit
    @heroku.rate_limit.info
  end
  
  def self.migrate_db(app_name)
    puts 'migrating db'
    heroku = Heroku::API.new(:api_key => 'f901d1da-4e4c-432f-9c9c-81da8363bb91')
    heroku = Heroku::API.new(:username => 'hello@biznobo.com', :password => '2025Ishmael')
    heroku.post_ps("#{app_name}", "rake db:migrate")
    heroku.post_ps("#{app_name}", "restart")
  end
  
  def set_db_config_vars(to, db_url)
    db_split = db_url.split(':')[1..3]
    db_user = db_split[0].split('//')[1]
    db_pass = db_split[1].split('@')[0]
    db_host = db_split[1].split('@')[1]
    db_port = db_split[2].split('/')[0].to_i
    db_name = db_split[2].split('/')[1]
    db_hash = {'DATABASE_URL' => db_url, 'DB_USER' => db_user, 'DB_PASS' => db_pass, 'DB_HOST' => db_host, 'DB_PORT' => db_port, 'DB_NAME' => db_name}
    @heroku.config_var.update(to, db_hash)
  end
  
  def get_librato_env_variables_for(app_name)
    puts "getting librato env variables for the app #{app_name}"
    vars = config_vars(app_name)
    librato_user = vars['LIBRATO_USER']
    librato_token = vars['LIBRATO_TOKEN']
    redis_url = vars['REDISTOGO_URL']
    librato_hash = {librato_user: librato_user, librato_token: librato_token, redis_url: redis_url}
  end
  
  def get_latest_api_release(app_name)
    puts "getting latest api release object"
    @heroku.release.list(app_name).to_a.last
  end
  
  def get_local_release_env_version
    puts "getting local release version from env var"
    ENV['RELEASE_VERSION']
  end
  
  def local_release_exists?
    puts "checking if local release version env var exists"
    ENV['RELEASE_VERSION'].nil? ? false : true
  end
  
  def set_release_env_and_slug_id(release_version, slug_id)
    puts "setting or updating new release version and slug id as env var"
    release_and_slug_hash = {'RELEASE_VERSION' => release_version, 'SLUG_ID' => slug_id}
    @heroku.config_var.update('sourcerevive', release_and_slug_hash)
  end
  
  def delete_app(app_name)
    puts "delete app method for the app #{app_name}"
    if "#{app_name}".include?('revivecrawler')
      puts "DANGER THE APP #{app_name} IS BEING DELETED"
      @heroku.app.delete(app_name)
    end
  end
  
  def restart_app(app_name)
    puts 'restarting app'
    @heroku.dyno.restart_all(app_name)
  end
  
  def add_pgbackups(to)
    puts 'adding pg backups'
    @heroku.addon.create(to, plan: "pgbackups")
  end
  
  def upgrade_postgres(to)
    puts 'upgrading postgres db'
    @heroku.addon.create(to, plan: "heroku-postgresql:standard-2")
    puts 'making new db the primary'
  end

  def add_redis(to)
    puts 'adding redis'
    @heroku.addon.create(to, plan: "redistogo:smedium")
  end
  
  def add_librato(to)
    puts 'adding librato'
    @heroku.addon.create(to, plan: "librato:nickel") 
  end
  
  def enable_log_runtime_metrics(app_name)
    puts 'enabling log runtime metrics'
    @heroku.app_feature.update(app_name, 'log-runtime-metrics', {'enabled'=>true})
  end
  
  def config_vars(app_name)
    @heroku.config_var.info(app_name)
  end
  
  def create_app(name)
    # logger.info "Creating #{name}"
    puts 'creating app'
    @heroku.app.create(name: name)
  end
  
  def copy_config(from, to)
    puts 'copying config'
    from_congig_vars = config_vars(from)
    from_congig_vars = from_congig_vars.except!('HEROKU_POSTGRESQL_TEAL_URL', 'PROXIMO_URL', 'LIBRATO_USER', 'LIBRATO_PASSWORD', 'LIBRATO_TOKEN', 'REDISTOGO_URL')
    @heroku.config_var.update(to, from_congig_vars)
  end
  
  def check_and_copy_slug(from, to)
    puts 'checking and copying slug'
    latest_api_release = get_latest_api_release(from)
    
    if local_release_exists? == true
      local_release_env_version = get_local_release_env_version
      puts "local release exists and the version is #{local_release_env_version}"
      
      if local_release_env_version.to_i == latest_api_release['version'].to_i || local_release_env_version.to_i > latest_api_release['version'].to_i
        puts "release exists and up to date OK to copy slug from local env: local version is #{latest_api_release['version']}"
        @heroku.release.create(to, slug: ENV['SLUG_ID'])
      else
        puts "updating local env release version and slug id and copying slug to version #{latest_api_release['version']}"
        set_release_env_and_slug_id(latest_api_release['version'], latest_api_release['slug']['id'])
        @heroku.release.create(to, slug: latest_api_release['slug']['id'])
      end
    else
      puts "local release does not exists: setting new local env release version and slug id: new version number is #{latest_api_release['version']}"
      set_release_env_and_slug_id(latest_api_release['version'], latest_api_release['slug']['id'])
      @heroku.release.create(to, slug: latest_api_release['slug']['id'])
    end
  end

  def copy_rack_and_rails_env_again(from, to)
    puts 'copying rack and rails env again'
    env_to_update = get_env_vars_for(from, ['RACK_ENV', 'RAILS_ENV'])
    @heroku.config_var.update(to, env_to_update) unless env_to_update.empty?
  end
  
  def get_env_vars_for(app_name, options=[])
    environments = {}
    options.each do |var|
      conf_var = @heroku.config_var.info(app_name)[var]
      if conf_var
        environments[var] = conf_var
      end
    end
    environments
  end
  
end