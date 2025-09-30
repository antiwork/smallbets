OmniAuth.config.test_mode = false
OmniAuth.config.logger = Rails.logger

if Rails.env.test?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :twitter2, 'test_client_id', 'test_client_secret'
  end
end