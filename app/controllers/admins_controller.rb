class AdminsController < ApplicationController
  before_filter :is_admin?

  def index
    @users = User.admin_search(params[:query]).order('created_at DESC').page(params[:page]).per_page(25)
  end

  def become_user
    user = User.find_by id: params[:user_id]
    cookies.delete(:auth_token)
    cookies.permanent[:auth_token] = user.auth_token
    redirect_to root_url
  end

  def edit_user
    @user = User.find_by id: params[:user_id]
  end

  def update_user
    user = User.find_by id: params[:user][:user_id]
    if user.update_attributes user_params
      flash[:notice] = "#{user.email} has been updated."
      redirect_to admins_path
    else
      flash[:error] = 'There was a problem updating.'
    end
  end

  private

  def is_admin?
    redirect_to dashboard_path, alert: "Not authorized" unless current_user.admin
  end

  def user_params
    params.require(:user).permit(:email, :minutes_available, :password)
  end

end
