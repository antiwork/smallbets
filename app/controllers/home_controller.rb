class HomeController < ApplicationController
  allow_unauthenticated_access
  layout false

  def index
    @user_count = User.count
  end
end