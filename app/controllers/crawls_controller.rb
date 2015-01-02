class CrawlsController < ApplicationController
  
  def index
  end
  
  def show
    @project = CobwebCrawlHelper.new(crawl_id: "8-8")
  end

  def new
    @project = Crawl.new
  end
  
  def create
    #raise
    Crawl.sites(params[:urls], params[:crawl][:name])
    redirect_to crawls_path
  end
  
end
