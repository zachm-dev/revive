class CrawlsController < ApplicationController
  before_action :authorize, :except => [:api_create, :migrate_db, :process_new_crawl]
  skip_before_action :verify_authenticity_token, :only => [:api_create, :migrate_db, :process_new_crawl]
  
  def index
    processor_names = ['processor', 'processor_one', 'processor_two', 'processor_three', 'processor_four']
    crawls_array = []
    processor_names.each do |processor|
      # crawls_array << Crawl.using("#{processor}").where(user_id: current_user.id).order('created_at').limit(10).flatten
      crawls_array << Crawl.using("#{processor}").where(user_id: current_user.id).order('created_at').flatten
    end
    page = params[:page].nil? ? 1 : params[:page] 
    @crawls = crawls_array.flatten.paginate(:page => page, :per_page => 10)
    
    # @crawls = Crawl.using(:processor).where(user_id: current_user.id).order('created_at').page(params[:page]).per_page(10)
  end
  
  def running
    
    processor_names = ['processor', 'processor_one', 'processor_two', 'processor_three', 'processor_four']
    crawls_array = []
    processor_names.each do |processor|
      # crawls_array << Crawl.using("#{processor}").where(status: 'running', user_id: current_user.id).order('created_at').limit(10).flatten
      crawls_array << Crawl.using("#{processor}").where(status: 'running', user_id: current_user.id).order('created_at').flatten
    end
    page = params[:page].nil? ? 1 : params[:page] 
    @crawls = crawls_array.flatten.paginate(:page => page, :per_page => 10)
    
    # @crawls = Crawl.using(:processor).where(status: 'running', user_id: current_user.id).order('created_at').page(params[:page]).per_page(10)
  end
  
  def finished
    
    processor_names = ['processor', 'processor_one', 'processor_two', 'processor_three', 'processor_four']
    crawls_array = []
    processor_names.each do |processor|
      # crawls_array << Crawl.using("#{processor}").where(status: 'finished', user_id: current_user.id).order('created_at').limit(10).flatten
      crawls_array << Crawl.using("#{processor}").where(status: 'finished', user_id: current_user.id).order('created_at').flatten
    end
    page = params[:page].nil? ? 1 : params[:page] 
    @crawls = crawls_array.flatten.paginate(:page => page, :per_page => 10)
    
    # @crawls = Crawl.using(:processor).where(status: 'finished', user_id: current_user.id).order('created_at').page(params[:page]).per_page(10)
  end
  
  def show
    processor_name = params['processor_name']
    @project = Crawl.using("#{processor_name}").where(user_id: current_user.id, id: params[:id]).first
    
    
    if @project.status == 'running' && !@project.redis_url.nil?
      begin
        redis = ActiveSupport::Cache.lookup_store(:redis_store, @project.redis_url)
        urls_found = "crawl/#{@project.id}/urls_found"
        expired_domains = "crawl/#{@project.id}/expired_domains"
        broken_domains = "crawl/#{@project.id}/broken_domains"
        progress = "crawl/#{@project.id}/progress"
        stats = redis.read_multi(urls_found, expired_domains, broken_domains, progress, raw: true)
        @urls_found = stats[urls_found].to_i
        @broken_domains = stats[broken_domains].to_i
        @expired_domains = stats[expired_domains].to_i
        @progress = stats[progress].to_f
      rescue
        @urls_found = @project.total_urls_found.to_i
        @broken_domains = @project.total_broken.to_i
        @expired_domains = @project.total_expired.to_i
      end
    else
      @urls_found = @project.total_urls_found.to_i
      @broken_domains = @project.total_broken.to_i
      @expired_domains = @project.total_expired.to_i
    end
    
    @stats_chart = Crawl.crawl_stats(@broken_domains, @expired_domains)
    # @sites = Site.find(@project.process_links_batches.map(&:site_id))
    @sites = @project.sites.page(params[:page]).per_page(10)
    @top_domains = @project.pages.where(available: 'true').limit(5)
  end

  def new
    @project = current_user.crawls.new
  end
  
  def new_keyword_crawl
    @project = current_user.crawls.new
  end
  
  def create
    Crawl.delay.save_new_crawl(current_user.id, params[:urls], params[:crawl])
    redirect_to crawls_path
  end
  
  def edit
    @project = Crawl.using(params["processor_name"]).find(params[:id])
  end
  
  def create_keyword_crawl
    Crawl.delay.save_new_keyword_crawl(current_user.id, params[:crawl][:keyword], params[:crawl])
    redirect_to crawls_path
  end
  
  def process_new_crawl
    @json = JSON.parse(request.body.read)
    puts "crawl to process hash #{@json["options"]}"
    Crawl.delay.decision_maker(@json["options"])
    render :layout => false
  end
  
  def api_create
    @json = JSON.parse(request.body.read)
    puts "here is the json hash #{@json["options"]}"
    Crawl.delay.start_crawl(@json["options"])
    SidekiqStats.delay.start(@json["options"])
    render :layout => false
  end
  
  def migrate_db
    @json = JSON.parse(request.body.read)
    processor_name = @json["options"]['processor_name']
    crawl = Crawl.using("#{processor_name}").find(@json["options"]["crawl_id"].to_i)
    puts "migrate_db: the current iteration is #{@json['options']['iteration'].to_i} for the crawl #{crawl.id}"
    puts "migrate db: the crawl id is #{crawl.id}"
    master_url = ENV['DATABASE_URL']
    slave_keys = ENV.keys.select{|k| k =~ /HEROKU_POSTGRESQL_.*_URL/}
    # slave_keys.delete_if{ |k| ENV[k] == master_url }
    db_url_name = (slave_keys - ["HEROKU_POSTGRESQL_COPPER_URL", "HEROKU_POSTGRESQL_AMBER_URL","HEROKU_POSTGRESQL_NAVY_URL","HEROKU_POSTGRESQL_WHITE_URL", "HEROKU_POSTGRESQL_BROWN_URL"])
    puts "migrate db: the db url name is #{db_url_name[0]}"
    db_url = ENV[db_url_name[0]]
    crawl.update(db_url: db_url)
    heroku = HerokuPlatform.new
    puts "setting the database variables"
    heroku.set_db_config_vars(crawl.heroku_app.name, db_url)
    puts "migrate_db: 60 seconds passed about to migrate the database"
    HerokuPlatform.migrate_db("revivecrawler#{crawl.id}")
    render :layout => false
  end
  
  def destroy
    crawl = HerokuApp.using(params["processor_name"]).find(params[:id])
    crawl.destroy
    redirect_to crawls_path
  end
  
  def delete_crawl
    crawl = Crawl.using(params["processor_name"]).find(params[:id])
    crawl.delete
    redirect_to crawls_path
  end
  
  def start_crawl
    Api.delay.process_new_crawl(user_id: current_user.id, 'processor_name' => params['processor_name'])
    redirect_to crawls_path
  end
  
  def stop_crawl
    puts "stop the crawl with the ID #{params[:id]} in the processor #{params['processor_name']}"
    Crawl.delay.stop_crawl(params[:id], 'processor_name' => params['processor_name'])
    redirect_to crawls_path
  end
  
end
