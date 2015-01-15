class SitesController < ApplicationController
  def index
  end
  
  def internal
    @site = Site.find(params[:id])
    @internal = @site.pages.where(internal: true).uniq.limit(50)
  end
  
  def external
    @site = Site.find(params[:id])
    @internal = @site.pages.where(internal: false).uniq.limit(50)
  end
  
  def broken
    @site = Site.find(params[:id])
    @internal = @site.pages.where(status_code: '404').uniq.limit(50)
  end

  def available
    @site = Site.find(params[:id])
    @internal = @site.pages.where(status_code: '0', internal: false).uniq.limit(50)
  end
  
end
