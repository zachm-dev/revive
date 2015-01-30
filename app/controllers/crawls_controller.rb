class CrawlsController < ApplicationController
  before_action :authorize, :except => [:api_create]
  skip_before_action :verify_authenticity_token, :only => [:api_create]
  
  def index
    #@sites = current_user.sites.all
    @crawls = current_user.crawls.order('created_at').page(params[:page]).per_page(4)
    Crawl.delay.update_all_crawl_stats(current_user.id)
  end
  
  def show
    #@project = CobwebCrawlHelper.new(crawl_id: "8-8")
    #@project = current_user.sites.find(params[:id])
    @project = current_user.crawls.find(params[:id])
    @stats_chart = Crawl.crawl_stats(params[:id])
    @gather_links_batches = @project.gather_links_batches.where(status: ["pending", "running"]).count
    @process_links_batches = @project.process_links_batches.where(status: ["pending", "running"]).count
    @top_domains = @project.pages.where(available: 'true').limit(5)
    @total_running_jobs = @gather_links_batches + @process_links_batches

    if @project.heroku_app.nil? || @project.heroku_app.verified == nil || @project.heroku_app.verified == 'pending'
      Namecheap.delay.check(crawl_id: @project.id)
    end
  end

  def new
    @project = current_user.crawls.new
  end
  
  def create
    #raise
    #GatherLinks.sites(current_user.id, params[:urls], params[:crawl])
    Crawl.delay.save_new_crawl(current_user.id, params[:urls], params[:crawl])
    redirect_to crawls_path
  end
  
  def api_create
    @json = JSON.parse(request.body.read)
    puts "here is the json hash #{@json["options"]}"
    GatherLinks.delay.start(@json["options"])
    render :layout => false
  end
  
  def stop_crawl
    Crawl.delay.stop_crawl(params[:id])
    redirect_to crawl_path_path(params[:id])
  end
  
end
