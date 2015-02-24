class DashboardController < ApplicationController
  before_filter :authorize
  
  def index
    @user_dashboard = current_user.user_dashboard
  end
end
