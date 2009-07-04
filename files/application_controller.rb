# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details
  layout 'main'
  gem 'json'
  require 'json'
  require 'authlogic'

  filter_parameter_logging :password
  before_filter :require_login
  helper_method :current_user, :redirect_back_or_default, :admin?, :logged_in?

  private

  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.record
  end

  def logged_in?
    return true if current_user
    false
  end

  def authentication_failed!
    store_location
    flash[:notice] = "You must be logged in"
    redirect_to root_url
  end

  def not_allowed! redirect = root_url
    flash[:error] = "You cannot access this"
    redirect_to redirect and return
  end

  def not_found! redirect = root_url
    flash[:notice] = "The requested item can not be found"
    redirect_to redirect and return
  end

  def require_login
    return authentication_failed! unless current_user
  end

  def store_location
    session[:return_to] = request.request_uri
  end

  def redirect_back_or_default(default = root_url)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end

end


class Array
  def and_join
    self.compact.join(", ").reverse.sub(",","dna ").reverse
  end
  def average
    return nil if self.empty?
    self.sum/self.size
  end
end
