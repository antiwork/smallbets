class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create oauth_callback oauth_failure ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render_rejection :too_many_requests }

  before_action :ensure_user_exists, only: :new

  def new
  end

  def destroy
    remove_push_subscription
    reset_authentication
    redirect_to root_url
  end

  def oauth_callback
    auth = request.env['omniauth.auth']
    
    if signed_in?
      # User is already signed in, connect their account
      connect_oauth_account(auth)
    else
      # User is not signed in, try to authenticate them
      authenticate_with_oauth(auth)
    end
  end

  def oauth_failure
    redirect_to new_session_url, alert: "Authentication failed. Please try again."
  end

  def oauth_disconnect
    if Current.user.oauth_connected?
      provider_name = Current.user.oauth_provider_name
      Current.user.disconnect_oauth_account
      redirect_to user_profile_url, notice: "Successfully disconnected your #{provider_name} account."
    else
      redirect_to user_profile_url, alert: "No OAuth account is connected."
    end
  end

  private
    def ensure_user_exists
      redirect_to first_run_url if User.none?
    end

    def render_rejection(status)
      flash.now[:alert] = "Too many requests or unauthorized."
      render :new, status: status
    end

    def remove_push_subscription
      if endpoint = params[:push_subscription_endpoint]
        Push::Subscription.destroy_by(endpoint: endpoint, user_id: Current.user.id)
      end
    end

    def connect_oauth_account(auth)
      if Current.user.connect_oauth_account(auth['provider'], auth['uid'], auth['info'])
        redirect_to user_profile_url, notice: "Successfully connected your #{auth['provider'].titleize} account!"
      else
        redirect_to user_profile_url, alert: "Failed to connect your #{auth['provider'].titleize} account. It may already be connected to another user."
      end
    end

    def authenticate_with_oauth(auth)
      user = User.find_by_oauth(auth['provider'], auth['uid'])
      
      if user
        start_new_session_for(user)
        redirect_to post_authenticating_url, notice: "Successfully signed in with #{auth['provider'].titleize}!"
      else
        # Try to find user by email from OAuth info
        email = auth.dig('info', 'email')
        if email.present?
          existing_user = User.active.non_suspended.find_by(email_address: email.downcase)
          if existing_user
            # User exists but hasn't connected OAuth yet - offer to connect
            session[:oauth_data] = {
              provider: auth['provider'],
              uid: auth['uid'],
              info: auth['info'].to_hash
            }
            redirect_to new_session_url, notice: "We found your account! Please sign in with your email to connect your #{auth['provider'].titleize} account."
          else
            # No existing user found
            redirect_to new_session_url, alert: "No Small Bets account found. Please sign in with your membership email first, then connect your #{auth['provider'].titleize} account from your profile."
          end
        else
          # No email in OAuth response
          redirect_to new_session_url, alert: "Unable to get email from #{auth['provider'].titleize}. Please sign in with your membership email first."
        end
      end
    end
end
