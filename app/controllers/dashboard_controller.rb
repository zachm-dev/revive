class DashboardController < ApplicationController
  before_filter :authorize
  
  def index
    @dashboard = current_user.user_dashboard
    @domains = Page.find(@dashboard.top_domains)
  end
end
