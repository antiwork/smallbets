class AuthTokens::ValidationsController < ApplicationController
  allow_unauthenticated_access

  rate_limit to: 10, within: 1.minute, with: -> { render_rejection :too_many_requests }

  def new
  end

  def create
    auth_token = AuthToken.lookup(email_address: session[:otp_email_address], token: params[:token], code: params[:code])

    if auth_token
      auth_token.use!
      session.delete(:otp_email_address)
      
      # If there's pending OAuth data, connect it to the user
      if session[:oauth_data].present?
        oauth_data = session[:oauth_data]
        if auth_token.user.connect_oauth_account(oauth_data['provider'], oauth_data['uid'], oauth_data['info'])
          flash[:notice] = "Successfully signed in and connected your #{oauth_data['provider'].titleize} account!"
        end
        session.delete(:oauth_data)
      end
      
      start_new_session_for(auth_token.user)
      redirect_to post_authenticating_url
    else
      redirect_to new_auth_tokens_validations_path, alert: "Invalid or expired token. Please try again."
    end
  end
end
