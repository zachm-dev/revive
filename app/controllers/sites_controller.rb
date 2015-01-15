class SitesController < ApplicationController
  def index
  end
  
  def all_urls
    @site = Site.find(params[:id])
    @urls = @site.pages.limit(50).uniq
  end
  
  def internal
    @site = Site.find(params[:id])
    @internal = @site.pages.where(internal: true).uniq.limit(50)
  end
  
  def external
    @site = Site.find(params[:id])
    @internal = @site.pages.where(internal: false).limit(50).uniq
  end
  
  def broken
    @site = Site.find(params[:id])
    @broken = @site.pages.where(status_code: '404').limit(50).uniq
  end

  def available
    @site = Site.find(params[:id])
    @internal = @site.pages.where(status_code: '0', internal: false).limit(50).uniq
  end
  
end
