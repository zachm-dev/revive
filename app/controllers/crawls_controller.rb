class CrawlsController < ApplicationController
  
  def index
    @sites = Site.all
  end
  
  def show
    #@project = CobwebCrawlHelper.new(crawl_id: "8-8")
    @project = Site.find(params[:id])
    @stats_chart = Crawl.stats(params[:id])
  end

  def new
    @project = Crawl.new
  end
  
  def create
    #raise
    Crawl.sites(params[:urls], params[:crawl])
    redirect_to crawls_path
  end
  
end
