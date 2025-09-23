class OauthCallbacksController < ApplicationController
  allow_unauthenticated_access only: %i[ create failure ]

  def create
    auth = request.env["omniauth.auth"]

    case auth.provider
    when "twitter2"
      handle_twitter_auth(auth)
    else
      redirect_to new_session_path, alert: "Authentication provider not supported."
    end
  end

  def failure
    redirect_to new_session_path, alert: "Authentication failed. Please try again."
  end

  private

  def handle_twitter_auth(auth)
    email = auth.info.email
    twitter_uid = auth.uid
    twitter_username = auth.info.nickname
    name = auth.info.name

    if user_signed_in?
      # User is already signed in, connect Twitter account
      Current.user.update!(
        twitter_uid: twitter_uid,
        twitter_username: twitter_username,
        twitter_url: "https://x.com/#{twitter_username}"
      )
      redirect_to user_profile_path, notice: "X account connected successfully!"
    else
      # Try to find user by Twitter UID first
      user = User.find_by(twitter_uid: twitter_uid)

      # If not found and email is present, try to find by email
      user ||= User.find_by(email_address: email) if email.present?

      if user
        # Update Twitter info if user exists
        user.update!(
          twitter_uid: twitter_uid,
          twitter_username: twitter_username,
          twitter_url: "https://x.com/#{twitter_username}"
        )
        authenticate_user(user)
        redirect_to root_path
      else
        # Create new user if email is present
        if email.present?
          user = User.create!(
            email_address: email,
            name: name.presence || User::DEFAULT_NAME,
            twitter_uid: twitter_uid,
            twitter_username: twitter_username,
            twitter_url: "https://x.com/#{twitter_username}"
          )
          authenticate_user(user)
          redirect_to root_path
        else
          redirect_to new_session_path, alert: "Email address is required for registration."
        end
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to new_session_path, alert: "Registration failed: #{e.message}"
  end

  def authenticate_user(user)
    session = user.sessions.create!
    cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
  end
end