class PlayController < ApplicationController
  def list
    require_user or return

    @games = Game.all
  end

  def play
    require_user or return
    @user = current_user

    @game = Game.where(:id => params[:id]).limit(1).first
    redirect_to play_list_url unless @game

    @user.game = @game
    @user.save
  end
end
