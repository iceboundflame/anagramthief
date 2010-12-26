class SessionsController < ApplicationController
  def create
    if params[:error]
      flash[:notice] = "Oops, an error occurred: "+params[:error]+" because "+params[:error_reason]+". Try again?"
      redirect_to(Facebook::CANVAS_URL)
      return
    end

    access_token_hash = MiniFB.oauth_access_token(
      Facebook::APP_ID, sessions_create_url, Facebook::SECRET, params[:code]
    )

    access_token = access_token_hash['access_token']

    @fb = MiniFB::OAuthSession.new(access_token, 'en_US')
    me = @fb.me

    unless user = User.find_by_uid(me['id'])
      user = User.create :uid => me['id']
    end

    user.update_from_graph(access_token, me)

    session[:uid] = me['id']
    session[:tok] = access_token

    redirect_to Facebook::CANVAS_URL
  end
end
