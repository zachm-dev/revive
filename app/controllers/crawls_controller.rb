class CrawlsController < ApplicationController
  
  def index
    @sites = Site.all
  end
  
  def show
    #@project = CobwebCrawlHelper.new(crawl_id: "8-8")
    @project = Site.find(params[:id])
  end

  def new
    @project = Crawl.new
  end
  
  def create
    Crawl.sites(params[:urls], params[:crawl][:name])
    redirect_to crawls_path
  end
  
end
