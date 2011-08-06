module ApplicationHelper
  def public_file_url(name) 
    URI.join(root_url, name).to_s
  end 

  def image_url(name) 
    URI.join(root_url, 'images/', name).to_s
  end 

  def play_in_canvas_url(game_id)
    URI.join(Anathief::Facebook::CANVAS_URL, "?game_id=#{game_id}").to_s
  end

  def inflect_noun(num, singular, plural)
    "#{num} #{num == 1 ? singular : plural}"
  end
end
