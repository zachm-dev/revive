class PlansController < ApplicationController

  def index
    if current_user
      redirect_to dashboard_path
    else
      render :layout => 'home'
    end
  end

end
