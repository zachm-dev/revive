class CrawlsController < ApplicationController
  before_action :authorize, :except => [:api_create, :fetch_new_crawl]
  skip_before_action :verify_authenticity_token, :only => [:api_create, :fetch_new_crawl]
  
  def index
    @crawls = current_user.crawls.order('created_at').page(params[:page]).per_page(4)
  end
  
  def show
    @project = current_user.crawls.find(params[:id])
    @stats_chart = Crawl.crawl_stats(params[:id])
    @sites = Site.find(@project.process_links_batches.map(&:site_id))
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
    begin
      if Page.last
        puts 'db has been migrated'
        # GatherLinks.delay.start(@json["options"])
        Crawl.delay.start_crawl(@json["options"])
        # SidekiqStats.delay.start(@json["options"])
      end
    rescue
      puts "rescue db migrate here is the crawl id #{@json["options"]["crawl_id"]}"
      HerokuPlatform.migrate_db("#{crawl.heroku_app.name}", options)
      sleep 60
      Api.delay.start_crawl(crawl_id: @json["options"]["crawl_id"])
    end

    render :layout => false
  end
  
  def fetch_new_crawl
    @json = JSON.parse(request.body.read)
    Crawl.delay.decision_maker(@json["options"]["user_id"].to_i)
    render :layout => false
  end
  
  def stop_crawl
    Crawl.delay.stop_crawl(params[:id])
    redirect_to crawl_path_path(params[:id])
  end
  
end
