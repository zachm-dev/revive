class AdminsController < ApplicationController
  before_filter :is_admin?

  def index
    @users = User.admin_search(params[:query]).includes(:subscription).page(params[:page]).per_page(25)
  end

  def become_user
    sign_in :user, User.find_by('email = ?', params[:email]), { bypass: true }
    redirect_to root_url
  end

  private

  def is_admin?
    redirect_to dashboard_path, alert: "Not authorized" unless current_user.admin
  end

end
