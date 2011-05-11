class ApplicationController < ActionController::Base
  helper_method :current_user, :user_signed_in?, :oauth_url
  helper_method :ordinalize
  before_filter :send_fucking_p3p

  def send_fucking_p3p # Goddamn this bullshit.
    response.headers['P3P'] = 'CP="NON CURa ADMa DEVa TAIa OUR BUS IND PHY UNI COM NAV DEM"';
  end

  def process_signed_request
    if request.post? and params[:signed_request] and
        MiniFB.verify_signed_request(Facebook::SECRET, params[:signed_request])
      fbinfo = MiniFB.signed_request_params(Facebook::SECRET, params[:signed_request])

      if fbinfo.has_key?('user_id')
        fb_uid = fbinfo['user_id']
        fb_tok = session[:fb_tok] = fbinfo['oauth_token']
        logger.info "Got rq from auth'd user #{fb_uid}"
        logger.info "Tok #{fb_tok}"

        me = MiniFB.get(fb_tok, 'me')
        unless @current_user = User.find_by_uid(fb_uid)
          raise "User account #{fb_uid} not found" #FIXME do we ever reach this?
          #@current_user = User.create :uid => fb_uid
        end
        @current_user.update_from_graph(fb_tok, me)

        session[:user_id] = @current_user.id
      else
        logger.info "Not logged in anymore"
        session[:fb_tok] = nil #FIXME what to do here? delete user_id too?
      end

      return true
    end
    return false
  end

  protected

  def current_user
    if (session[:user_id])
      @current_user ||= User.find(session[:user_id])
    else
      @current_user
    end
  end

  def user_signed_in?
    !!current_user
  end

  def require_user
    signed_in = user_signed_in?
    redirect_to root_url unless signed_in
    signed_in
  end

  def oauth_url
    MiniFB.oauth_url(Facebook::APP_ID, sessions_fb_callback_url, :scope => '')
  end

  def ordinalize(value)
    case value.to_s
    when /^[0-9]*[1][0-9]$/
      suffix = "th"
    when /^[0-9]*[1]$/
      suffix = "st"
    when /^[0-9]*[2]$/
      suffix = "nd"
    when /^[0-9]*[3]$/
      suffix = "rd"
    else
      suffix = "th"
    end

    return value.to_s << suffix
  end

  def random_guest_name
    return "Guest #{100000 + rand(10000)}"
  end
end
