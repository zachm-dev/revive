class CrawlsController < ApplicationController
  before_filter :authorize
  
  def index
    @sites = current_user.sites.all
  end
  
  def show
    #@project = CobwebCrawlHelper.new(crawl_id: "8-8")
    @project = current_user.sites.find(params[:id])
    @stats_chart = Crawl.stats(params[:id])
  end

  def new
    @project = current_user.crawls.new
  end
  
  def create
    #raise
    Crawl.sites(current_user.id, params[:urls], params[:crawl])
    redirect_to crawls_path
  end
  
end
