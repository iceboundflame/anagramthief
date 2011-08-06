class SessionsController < ApplicationController
  def fb_callback
    if params[:error]
      flash[:notice] = "Oops, an error occurred: "+params[:error]+" because "+params[:error_reason]+". Try again?"
      redirect_to(Anathief::Facebook::CANVAS_URL)
      return
    end

    access_token_hash = MiniFB.oauth_access_token(
      Anathief::Facebook::APP_ID, sessions_fb_callback_url, Anathief::Facebook::SECRET, params[:code]
    )

    access_token = access_token_hash['access_token']

    @fb = MiniFB::OAuthSession.new(access_token, 'en_US')
    me = @fb.me

    unless user = User.find_by_uid(me['id'])
      logger.info "New FB user #{me['id']}"
      user = User.create :uid => me['id']
    end

    user.update_from_graph(access_token, me)

    session[:user_id] = user.id
    session[:fb_tok] = access_token

    redirect_to Anathief::Facebook::CANVAS_URL
  end

  def guest_in
    name = params[:name].strip
    name = params[:placeholder_name].strip unless name && !name.empty?
    name = random_guest_name unless name && !name.empty?

    user = User.create :uid => nil,
      :name => "#{name} (Guest)",
      :first_name => name,
      :last_name => "(Guest)"

    session[:user_id] = user.id
    session[:fb_tok] = nil

    logger.info "New guest user #{user.id} : #{user.name}"

    respond_to do |format|
      format.json { render :json => {:status => true,
        :user_id => user.id, :login_token => generate_login_token(user.id)} }
      format.html { redirect_to root_url }
    end
  end

  def logout
    session[:user_id] = session[:fb_tok] = session[:go_to_game_id] = nil

    redirect_to root_url
  end
end
