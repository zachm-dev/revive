class UsersController < ApplicationController
  before_action :set_user, only: [:edit, :update]
  
  def new
    @user = User.new
  end
  
  def account

    @user = current_user
    @plan = current_user.subscription.plan

  end

  def create
    @user = User.new(params[:user].permit(:email, :password, :password_confirmation))
    if @user.save
      session[:user_id] = @user.id
      redirect_to root_url, notice: "Thank you for signing up!"
    else
      render 'new'
    end
  end


  def update
    respond_to do |format|
      if @user == current_user && @user.update(user_params)
        format.html { redirect_to account_path, notice: 'Account was successfully updated.' }
      else
        format.html { redirect_to account_path }
      end
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(:first_name, :last_name, :phone, :email, :address_1, :address_2, :city, :zip, :state, :country, :password, :password_confirmation)
  end

end
