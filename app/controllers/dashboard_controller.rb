class DashboardController < ApplicationController
  before_filter :authorize
  
  def index
    @dashboard = current_user.user_dashboard
  end
end
