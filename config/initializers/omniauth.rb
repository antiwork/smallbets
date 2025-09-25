Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter2, ENV['TWITTER_CLIENT_ID'], ENV['TWITTER_CLIENT_SECRET'], {
    scope: 'users.read'
  }
end

# Configure OmniAuth to handle CSRF protection
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true
