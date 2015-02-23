class PendingCrawlsController < ApplicationController
  before_action :authorize, :except => [:sort]
  
  def index
    @crawls = current_user.heroku_apps.where(status: "pending").order(:position).includes(:crawl)
    # @crawls = current_user.heroku_apps.order(:pos).limit(5).includes(:crawl)
  end
  
  def sort
    params[:heroku_app].each_with_index do |id, index|
      HerokuApp.update(id, position: index+1)
    end
    render nothing: true
  end
  
end
