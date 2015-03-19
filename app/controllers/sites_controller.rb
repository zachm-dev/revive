class SitesController < ApplicationController
  before_filter :authorize
  
  def index
    crawl = Crawl.using(:processor).find(params[:id])
    @sites = crawl.sites.all
  end
  
  def show
    @site = Site.using(:processor).find(params[:id])
    @stats_chart = Crawl.site_stats(params[:id])
  end
  
  def all_urls
    @site = Site.using(:processor).find(params[:id])
    @urls = @site.pages.limit(50).uniq
  end
  
  def broken
    @crawl = Crawl.using(:processor).find(params[:id])
    # @broken = @crawl.pages.where(status_code: '404').limit(50).uniq
    @broken = @crawl.pages.where(status_code: '404')
    @pages = @broken.page(params[:page]).per_page(25)
    
    respond_to do |format|
      format.html
      format.csv { send_data @broken.to_csv }
    end
    
  end

  def available
    @crawl = Crawl.using(:processor).find(params[:id])
    @available = @crawl.pages.where(available: 'true')

    unless @crawl.moz_da.nil? || @crawl.moz_da == 0
      moz_da = @available.where('da >= ?', @crawl.moz_da).order("#{sort} DESC")
    end
    
    unless @crawl.majestic_tf.nil? || @crawl.majestic_tf == 0
      majestic_tf = @available.where('trustflow >= ?', @crawl.majestic_tf).order("#{sort} DESC")
    end
    
    sort = params[:sort].nil? ? 'id' : params[:sort]
    
    if moz_da && majestic_tf
      if (moz_da.count + majestic_tf.count) > 0
        @pages = (moz_da + majestic_tf).page(params[:page]).per_page(25)
      else
        @pages = @available.order("#{sort} DESC").page(params[:page]).per_page(25)
      end
    else
      @pages = @available.order("#{sort} DESC").page(params[:page]).per_page(25)
    end
    
    respond_to do |format|
      format.html
      format.csv { send_data @available.to_csv }
    end
    
  end
  
  def save_bookmarked
    Page.using(:processor).where(id: params[:page_ids]).update_all(bookmarked: true)
    redirect_to bookmarked_sites_path(params[:id])
  end
  
  def unbookmark
    Page.using(:processor).where(id: params[:page_ids]).update_all(bookmarked: false)
    redirect_to bookmarked_sites_path(params[:id])
  end
  
  def bookmarked
    @crawl = Crawl.using(:processor).find(params[:id])
    sort = params[:sort].nil? ? 'id' : params[:sort]
    @bookmarked = @crawl.pages.where(bookmarked: true)
    @pages = @bookmarked.order("#{sort} DESC").page(params[:page]).per_page(25)
    
    respond_to do |format|
      format.html
      format.csv { send_data @bookmarked.to_csv }
    end
    
  end
  
end
