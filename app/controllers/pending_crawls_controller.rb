class PendingCrawlsController < ApplicationController
  before_action :authorize, :except => [:sort]
  
  def index
    @crawls = HerokuApp.using(:processor).where(status: "pending", user_id: current_user.id).order(:position).includes(:crawl)
    # @crawls = current_user.heroku_apps.order(:pos).limit(5).includes(:crawl)
  end
  
  def sort
    params[:heroku_app].each_with_index do |id, index|
      HerokuApp.using(:processor).update(id, position: index+1)
    end
    render nothing: true
  end
  
end
