Rails.application.routes.draw do
  # Top-level room slug routing (must come before other catch-alls that could conflict)
  constraints(RoomSlugConstraint.new) do
    get "/:slug", to: "rooms#show", as: :room_slug
  end

  # Redirect www.smallbets.com to smallbets.com
  constraints(host: /^www\.smallbets\.com/) do
    match "(*any)", to: redirect { |params, request|
      "https://smallbets.com/#{params[:any]}#{request.query_string.present? ? '?' + request.query_string : ''}"
    }, via: :all
  end

  constraints(AdminConstraint.new) do
    root to: "feed#index"
  end

  constraints(lambda { |req| req.session[:user_id].present? }) do
    # TODO: Remove once the temporary feed gating is no longer needed.
    root to: "feed#index", as: :authenticated_root
  end

  constraints(lambda { |req| req.session[:user_id].blank? }) do
    root to: "marketing#show", as: :unauthenticated_root
  end

  get "/join", to: "marketing#join", as: :join_now
  get "/api/stats", to: "marketing#stats", defaults: { format: :json }
  get "/chat", to: "welcome#show"
  get "/talk", to: "welcome#show", as: :talk

  namespace :api, defaults: { format: :json }, module: :api do
    namespace :videos do
      resources :thumbnails, only: :index
    end
  end

  resource :first_run

  resource :session do
    scope module: "sessions" do
      resources :transfers, only: %i[ show update ]
    end
  end

  resources :auth_tokens, only: %i[create]
  namespace :auth_tokens do
    resource :validations, only: %i[new create]
  end
  get "auth_tokens/validate/:token", to: "auth_tokens/validations#create", as: :sign_in_with_token

  resource :account do
    scope module: "accounts" do
      resources :users

      resources :bots do
        scope module: "bots" do
          resource :key, only: :update
        end
      end

      resource :join_code, only: :create
      resource :logo, only: %i[ show destroy ]
      resource :custom_styles, only: %i[ edit update ]
    end
  end

  direct :fresh_account_logo do |options|
    route_for :account_logo, v: Current.account&.updated_at&.to_fs(:number), size: options[:size]
  end

  resources :qr_code, only: :show

  scope module: :users do
    resource :preference, only: [ :update ]
    resource :email_subscription, only: %i[ show update ]
  end

  resources :users, only: :show do
    scope module: "users" do
      resource :avatar, only: %i[ show destroy ]
      resources :messages, only: %i[ index ] do
        get :page, on: :collection
      end
      resources :searches, only: %i[ create ] do
        delete :clear, on: :collection
      end

      scope defaults: { user_id: "me" } do
        resource :sidebar, only: :show
        resource :profile
        resources :push_subscriptions do
          scope module: "push_subscriptions" do
            resources :test_notifications, only: :create
          end
        end
      end
    end
    resources :blocks, only: [ :create ] do
      collection do
        delete "", to: "blocks#destroy"
      end
    end
  end

  namespace :autocompletable do
    resources :users, only: :index
  end

  direct :fresh_user_avatar do |user, options|
    route_for :user_avatar, user.avatar_token, v: user.updated_at.to_fs(:number)
  end

  get "join/:join_code", to: "users#new", as: :join
  post "join/:join_code", to: "users#create"

  resources :rooms do
    resources :messages do
      resources :unreads, only: %i[ create ], module: "messages"
    end

    post ":bot_key/messages", to: "messages/by_bots#create", as: :bot_messages

    scope module: "rooms" do
      resource :refresh, only: :show
      resource :settings, only: :show
      resource :stats, only: :show
      resource :involvement, only: %i[ show update ] do
        get :notifications_ready, on: :member
      end
      resources :merges, only: :create
    end

    get "@:message_id", to: "rooms#show", as: :at_message
  end

  namespace :rooms do
    resources :opens
    resources :closeds
    resources :directs
    resources :threads, only: %i[ new edit update destroy ]

    post ":bot_key/directs", to: "directs/by_bots#create", as: :bot_directs
  end

  resources :messages do
    scope module: "messages" do
      resources :boosts
      resources :bookmarks, only: %i[ create ] do
        collection do
          delete "", to: "bookmarks#destroy"
        end
      end
      resource :answer, only: %i[ create destroy ]
    end
  end
  scope module: "messages" do
    resources :profiles, only: %i[show], as: :mention_profile
  end

  resource :inbox, only: %i[ show ] do
    member do
      get :mentions
      get :threads
      get :notifications
      get :messages
      get :bookmarks
      get :answers
      post :clear
    end
    scope path: "/paged", as: :paged do
      resources :mentions, only: %i[ index ], controller: "inboxes/mentions"
      resources :threads, only: %i[ index ], controller: "inboxes/threads"
      resources :notifications, only: %i[ index ], controller: "inboxes/notifications"
      resources :messages, only: %i[ index ], controller: "inboxes/messages"
      resources :bookmarks, only: %i[ index ], controller: "inboxes/bookmarks"
      resources :answers, only: %i[ index ], controller: "inboxes/answers"
    end
  end

  resources :searches, only: %i[ index create ] do
    collection do
      delete :clear
      get :page
    end
  end

  namespace :webhooks, defaults: { format: :json } do
    namespace :gumroad do
      post "/refunds/:webhook_secret", to: "refunds#create"
      post "/users/:webhook_secret", to: "users#create"
    end
  end

  resource :unfurl_link, only: :create

  resources :configurations, only: [] do
    get :ios_v1, on: :collection
  end

  get "webmanifest"    => "pwa#manifest"
  get "service-worker" => "pwa#service_worker"

  get "library" => "library#index", as: :library
  get "library/download/:id" => "library#download", as: :library_download
  get "library/downloads/:id" => "library#downloads", as: :library_downloads
  get "library/:id" => "library#show", as: :library_watch
  resources :library_sessions, only: [] do
    resource :watch_history, only: [ :create, :update ], controller: "library/watch_histories"
  end

  resources :promotions, only: [:create]
  resources :feed, only: [:destroy], controller: "feed"

  get "experts" => "experts#show"

  get "up" => "rails/health#show", as: :rails_health_check

  # Stats routes
  get "/stats", to: "stats#index"
  get "stats/daily/month_data", to: "stats#month_data", as: "stats_month_data"
  get "stats/daily/:month", to: "stats#today", as: "stats_daily_month"
  get "stats/daily", to: "stats#today"
  get "stats/monthly", to: "stats#month"
  get "stats/yearly", to: "stats#year"
  get "stats/all", to: "stats#all"
  get "stats/rooms", to: "stats#rooms"
end
