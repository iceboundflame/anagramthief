class ApplicationController < ActionController::Base
  helper_method :current_user, :user_signed_in?, :oauth_url
  before_filter :process_signed_request
  before_filter :send_fucking_p3p

  attr_accessor :landed_on_canvas

  def send_fucking_p3p # Goddamn this bullshit.
    response.headers['P3P'] = 'CP="NON CURa ADMa DEVa TAIa OUR BUS IND PHY UNI COM NAV DEM"';
  end

  def process_signed_request
    if request.post? and params[:signed_request] and
        MiniFB.verify_signed_request(Facebook::SECRET, params[:signed_request])
      fbinfo = MiniFB.signed_request_params(Facebook::SECRET, params[:signed_request])

      if fbinfo.has_key?('user_id')
        uid = session[:uid] = fbinfo['user_id']
        tok = session[:tok] = fbinfo['oauth_token']
        logger.info "Got rq from auth'd user #{uid}"
        logger.info "Tok #{tok}"

        unless @current_user = User.find_by_uid(uid)
          me = MiniFB.get(tok, 'me')
          @current_user = User.create :uid => uid
        end
        @current_user.update_from_graph(tok, me)
      else
        logger.info "Not logged in anymore"
        session[:uid] = session[:tok] = nil
      end

      @landed_on_canvas = true
    end
  end

  protected

  def current_user
    if (session[:uid])
      @current_user ||= User.find_by_uid(session[:uid])
    else
      @current_user
    end
  end

  def user_signed_in?
    !!current_user
  end

  def require_user
    signed_in = user_signed_in?
    redirect_to oauth_url unless signed_in
    signed_in
  end

  def oauth_url
    MiniFB.oauth_url(Facebook::APP_ID, sessions_create_url, :scope => '')
  end
end
