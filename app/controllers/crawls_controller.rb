class CrawlsController < ApplicationController
  before_action :authorize, :except => [:api_create, :migrate_db, :process_new_crawl]
  skip_before_action :verify_authenticity_token, :only => [:api_create, :migrate_db, :process_new_crawl]
  
  def index
    @crawls = Crawl.using(:processor).where(user_id: current_user.id).order('created_at').page(params[:page]).per_page(10)
  end
  
  def running
    @crawls = Crawl.using(:processor).where(status: 'running', user_id: current_user.id).order('created_at').page(params[:page]).per_page(10)
  end
  
  def finished
    @crawls = Crawl.using(:processor).where(status: 'finished', user_id: current_user.id).order('created_at').page(params[:page]).per_page(10)
  end
  
  def show
    @project = Crawl.using(:processor).where(user_id: current_user.id, id: params[:id]).first
    
    
    if @project.status == 'running' && !@project.redis_url.nil?
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
    @project = Crawl.using(:processor).find(params[:id])
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
    # SidekiqStats.delay.start(@json["options"])
    render :layout => false
  end
  
  def migrate_db
    @json = JSON.parse(request.body.read)
    processor_name = @json["options"]['processor_name']
    crawl = Crawl.using("#{processor_name}").find(@json["options"]["crawl_id"].to_i)
    puts "the crawl id is #{crawl.id}"
    master_url = ENV['DATABASE_URL']
    slave_keys = ENV.keys.select{|k| k =~ /HEROKU_POSTGRESQL_.*_URL/}
    slave_keys.delete_if{ |k| ENV[k] == master_url }
    db_url = ENV[slave_keys.first]
    crawl.update(db_url: db_url)
    heroku = HerokuPlatform.new
    puts "setting the database variables"
    heroku.set_db_config_vars(crawl.heroku_app.name, db_url)
    puts "migrating the database"
    HerokuPlatform.migrate_db(crawl.heroku_app.name)
    render :layout => false
  end
  
  def destroy
    crawl = HerokuApp.using(:processor).find(params[:id])
    crawl.destroy
    redirect_to crawls_path
  end
  
  def delete_crawl
    crawl = Crawl.using(:processor).find(params[:id])
    crawl.delete
    redirect_to crawls_path
  end
  
  def start_crawl
    Api.delay.process_new_crawl(user_id: current_user.id)
    redirect_to crawls_path
  end
  
  def stop_crawl
    Crawl.delay.stop_crawl(params[:id], 'processor_name' => params['processor_name'])
    redirect_to crawls_path
  end
  
end
