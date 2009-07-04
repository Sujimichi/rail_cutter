class UserSessionsController < ApplicationController
  skip_before_filter :require_login, :just => [:new]

  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = "Oh, U again is it?"
      redirect_to root_url
    else
      flash[:error] = "hmmm, I dont like you"
      redirect_to root_url
    end
  end

  def destroy
    @user_session = UserSession.find
    @user_session.destroy
    flash[:notice] = "Successfully logged out."
    redirect_to root_url
  end

end
