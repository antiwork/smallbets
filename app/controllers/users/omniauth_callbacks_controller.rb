class Users::OmniauthCallbacksController < ApplicationController
  include Authentication
  
  skip_before_action :verify_authenticity_token, only: [ :twitter, :failure ]
  before_action :require_authentication, only: [ :disconnect ]

  def twitter
    auth_hash = request.env["omniauth.auth"]
    login_only = session.delete(:oauth_login_only)
    
    if auth_hash.blank?
      redirect_to new_session_path, alert: "Authentication failed. Please try again."
      return
    end

    if login_only
      handle_login(auth_hash)
    else
      handle_connect(auth_hash)
    end
  end

  private

  def handle_login(auth_hash)
    user = User.find_by(twitter_uid: auth_hash["uid"])
    
    if user.present?
      start_new_session_for(user)
      redirect_to root_path, notice: "Signed in with X successfully!"
    else
      redirect_to new_session_path, alert: "No account found with this X account. Please sign in with email first and connect your X account."
    end
  end

  def handle_connect(auth_hash)
    unless Current.user
      redirect_to new_session_path, alert: "Please sign in first to connect your X account."
      return
    end

    begin
      Current.user.update!(
        twitter_uid: auth_hash["uid"],
        twitter_oauth_token: auth_hash.dig("credentials", "token"),
        twitter_oauth_refresh_token: auth_hash.dig("credentials", "refresh_token"),
        twitter_screen_name: auth_hash.dig("info", "nickname"),
        twitter_profile_image: auth_hash.dig("info", "image"),
        twitter_connected_at: Time.current,
        twitter_url: "https://x.com/#{auth_hash.dig('info', 'nickname')}"
      )
      
      redirect_to user_profile_path("me"), notice: "Successfully connected your X account!"
    rescue => e
      Rails.logger.error "X OAuth Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to user_profile_path("me"), alert: "Failed to connect X account. Please try again."
    end
  end

  public

  def initiate_login
    session[:oauth_login_only] = true
    render inline: <<-HTML, layout: false
      <!DOCTYPE html>
      <html>
        <body>
          <form id="oauth-form" action="/auth/twitter2" method="post">
            <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
          </form>
          <script>document.getElementById('oauth-form').submit();</script>
        </body>
      </html>
    HTML
  end

  def failure
    error_message = request.params[:message] || "Authentication failed"
    Rails.logger.error "OmniAuth Failure: #{error_message}"
    redirect_to user_profile_path("me"), alert: "X authentication failed: #{error_message}"
  end

  def disconnect
    Current.user.update!(
      twitter_uid: nil,
      twitter_oauth_token: nil,
      twitter_oauth_refresh_token: nil,
      twitter_screen_name: nil,
      twitter_profile_image: nil,
      twitter_connected_at: nil
    )
    
    redirect_to user_profile_path("me"), notice: "X account disconnected successfully!"
  end

end
