module ApplicationHelper
  def public_file_url(name) 
    URI.join(root_url, name).to_s
  end 

  def image_url(name) 
    URI.join(root_url, 'images/', name).to_s
  end 

  def define_word_url(word) 
    URI.join('http://www.wordnik.com/words/', word).to_s
  end 
end
