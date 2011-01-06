class User < ActiveRecord::Base
  belongs_to :game
  has_many :user_game_records
  has_many :game_records, :through => :user_game_records

  #def facebook_friends(access_token)
    #@graph ||= MiniFB::OAuthSession.new(access_token)
    #@graph.me.friends['data'].map { |x| {:label => x.name, :id => x.id} } + [{:label => self.name, :id => self.uid}]
  #end

  def id_s
    id.to_s
  end
  
  def update_from_graph(access_token, me=nil)
    @graph ||= MiniFB::OAuthSession.new(access_token)

    me = @graph.me unless me

    self.name = me['name']
    self.first_name = me['first_name']
    self.last_name = me['last_name']

    self.save
  rescue
    logger.error "Error in update_from_graph: #{$!}"
  end

  def profile_pic
    "http://graph.facebook.com/#{self.uid}/picture?type=square"
  end
end
