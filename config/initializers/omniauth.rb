Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter2,
           ENV['TWITTER_CLIENT_ID'],
           ENV['TWITTER_CLIENT_SECRET'],
           scope: 'users.read offline.access'
end