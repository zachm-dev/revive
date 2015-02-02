class SitesController < ApplicationController
  before_filter :authorize
  
  def index
    crawl = current_user.crawls.find(params[:id])
    @sites = crawl.sites.all
  end
  
  def show
    @site = current_user.sites.find(params[:id])
    @stats_chart = Crawl.site_stats(params[:id])
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
    #@site = Site.find(params[:id])
    @crawl = Crawl.find(params[:id])
    @broken = @crawl.pages.where(status_code: '404').limit(50).uniq
  end

  def available
    @crawl = Crawl.find(params[:id])
    @available = @crawl.pages.where(available: 'true')
    unless @crawl.moz_da.nil? || @crawl.moz_da == 0
      moz_da = @available.where('da >= ?', @crawl.moz_da.to_s)
    end
    
    unless @crawl.majestic_tf.nil? || @crawl.majestic_tf == 0
      majestic_tf = @available.where('trustflow >= ?', @crawl.majestic_tf.to_s)
    end
    
    
    if moz_da && majestic_tf
      if (moz_da.count + majestic_tf.count) > 0
        @pages = (moz_da + majestic_tf).page(params[:page]).per_page(25)
      else
        @pages = @available.page(params[:page]).per_page(25)
      end
    else
      @pages = @available.page(params[:page]).per_page(25)
    end
    
    # if @crawl.heroku_app.nil? || @crawl.heroku_app.verified == 'pending' || @crawl.heroku_app.verified == nil
    #   @processing = 'true'
    #   @available = @crawl.pages.where(status_code: '0', internal: false).limit(50).uniq
    #   Namecheap.delay.check(crawl_id: @crawl.id)
    # else
    #   @available = @crawl.pages.where(available: 'true')
    # end
    
    # if @crawl.pages.where(verified: true).count == 0
    #   @processing = 'true'
    #   @available = @crawl.pages.where(status_code: '0', internal: false).limit(50).uniq
    #   Namecheap.delay.check(crawl_id: @crawl.id)
    # else
    #   @available = @crawl.pages.where(available: 'true')
    # end
  end
  
end
