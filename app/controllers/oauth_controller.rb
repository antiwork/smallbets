class OauthController < ApplicationController
  allow_unauthenticated_access only: [:callback]

  def callback
    auth_info = request.env["omniauth.auth"]
    
    if signed_in?
      Current.user.update!(twitter_uid: auth_info.uid)
      redirect_to user_profile_path, notice: "X account connected successfully!"
    else
      user = User.find_by(twitter_uid: auth_info.uid) ||
             User.find_by(email_address: auth_info.info.email)
      
      if user
        user.update!(twitter_uid: auth_info.uid) unless user.twitter_uid
        start_new_session_for(user)
        redirect_to post_authenticating_url
      else
        redirect_to new_session_path, alert: "No account found. Please sign up first or use email login."
      end
    end
  rescue
    redirect_to signed_in? ? user_profile_path : new_session_path, alert: "Authentication failed."
  end

  def disconnect
    Current.user.update!(twitter_uid: nil)
    redirect_to user_profile_path, notice: "X account disconnected."
  end
end