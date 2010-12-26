module ApplicationHelper
  def public_file_url(name) 
    URI.join(root_url, name).to_s
  end 

  def image_url(name) 
    URI.join(root_url, 'images/', name).to_s
  end 

  def oauth_url
    MiniFB.oauth_url(Facebook::APP_ID, sessions_create_url, :scope => '')
  end
end
