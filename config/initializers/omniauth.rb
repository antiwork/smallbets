Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter2, 
           ENV["X_CLIENT_ID"], 
           ENV["X_CLIENT_SECRET"],
           scope: "tweet.read users.read offline.access"
end
