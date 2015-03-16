class CrawlsController < ApplicationController
  before_action :authorize, :except => [:api_create, :fetch_new_crawl, :migrate_db]
  skip_before_action :verify_authenticity_token, :only => [:api_create, :fetch_new_crawl, :migrate_db]
  
  def index
    @crawls = current_user.crawls.order('created_at').page(params[:page]).per_page(4)
  end
  
  def running
    @crawls = current_user.crawls.where(status: 'running').order('created_at').page(params[:page]).per_page(4)
  end
  
  def finished
    @crawls = current_user.crawls.where(status: 'finished').order('created_at').page(params[:page]).per_page(4)
  end
  
  def show
    @project = current_user.crawls.find(params[:id])
    
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
    
    @stats_chart = Crawl.crawl_stats(params[:id])
    # @sites = Site.find(@project.process_links_batches.map(&:site_id))
    @sites = @project.sites
    @top_domains = @project.pages.where(available: 'true').limit(5)
  end

  def new
    @project = current_user.crawls.new
  end
  
  def create
    # raise
    #GatherLinks.sites(current_user.id, params[:urls], params[:crawl])
    Crawl.delay.save_new_crawl(current_user.id, params[:urls], params[:crawl])
    redirect_to crawls_path
  end
  
  def new_keyword_crawl
    @project = current_user.crawls.new
  end
  
  def create_keyword_crawl
    # raise
    Crawl.delay.save_new_keyword_crawl(current_user.id, params[:crawl][:keyword], params[:crawl])
    redirect_to crawls_path
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
    crawl = Crawl.find(@json["options"]["crawl_id"].to_i)
    puts "the crawl id is #{crawl.id}"
    master_url = ENV['DATABASE_URL']
    slave_keys = ENV.keys.select{|k| k =~ /HEROKU_POSTGRESQL_.*_URL/}
    slave_keys.delete_if{ |k| ENV[k] == master_url }
    db_url = ENV[slave_keys.first]
    heroku = HerokuPlatform.new
    puts "setting the database variables"
    heroku.set_db_config_vars(crawl.heroku_app.name, db_url)
    puts "migrating the database"
    HerokuPlatform.migrate_db(crawl.heroku_app.name)
    render :layout => false
  end
  
  def fetch_new_crawl
    @json = JSON.parse(request.body.read)
    Crawl.delay.decision_maker(@json["options"]["user_id"].to_i)
    render :layout => false
  end
  
  def call_crawl
    @json = JSON.parse(request.body.read)
    Api.delay.start_crawl(crawl_id: @json["options"]["crawl_id"].to_i)
    render :layout => false
  end
  
  def stop_crawl
    Crawl.delay(retry: false).stop_crawl(params[:id])
    redirect_to crawls_path
  end
  
end
