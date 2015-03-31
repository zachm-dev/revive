class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  
  def copy_to_clipboard
    render :layout => false
    msg = Clipboard.copy(params['msg'])
  end
  
  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
    # @current_user ||= User.using(:main_shard).find_by_auth_token!(cookies[:auth_token]) if cookies[:auth_token]
  end
  helper_method :current_user

  def authorize
    redirect_to login_url, alert: "Not authorized" if current_user.nil?
  end
  

  
end
