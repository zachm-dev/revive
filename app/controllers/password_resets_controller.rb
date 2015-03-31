class PasswordResetsController < ApplicationController
  def new
  end
  
  def create
    user = User.using(:main_shard).find_by_email(params[:email])
  end
end
