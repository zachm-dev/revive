class CrawlsController < ApplicationController
  #before_filter :authorize
  skip_before_action :verify_authenticity_token
  
  def index
    #@sites = current_user.sites.all
    @crawls = current_user.crawls.all
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
  end

  def new
    @project = current_user.crawls.new
  end
  
  def create
    #raise
    #GatherLinks.sites(current_user.id, params[:urls], params[:crawl])
    #redirect_to crawls_path
    @json = JSON.parse(request.body.read)
  end
  
end
