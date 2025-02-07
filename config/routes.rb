Rails.application.routes.draw do
  # Direct routes must be defined outside of any scope
  direct :fresh_account_logo do |options|
    route_for :account_logo, v: Current.account&.updated_at&.to_fs(:number), size: options[:size]
  end

  direct :fresh_user_avatar do |user, options|
    route_for :user_avatar, user.avatar_token, v: user.updated_at.to_fs(:number)
  end

  # Authentication routes outside of /chat scope
  resource :session do
    scope module: "sessions" do
      resources :transfers, only: %i[ show update ]
    end
  end

  # Chat scope containing the main application routes
  scope '/chat' do
    root to: "rooms#index", as: :chat_root

    resource :first_run

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

    resources :qr_code, only: :show

    scope module: :users do
      resource :preference, only: [:update]
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
    end

    namespace :autocompletable do
      resources :users, only: :index
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
      resources :threads

      post ":bot_key/directs", to: "directs/by_bots#create", as: :bot_directs
      post ":bot_key/threads", to: "threads/by_bots#create", as: :bot_threads
    end

    resources :messages do
      scope module: "messages" do
        resources :boosts
        resources :bookmarks, only: %i[ create ] do
          collection do
            delete '', to: 'bookmarks#destroy'
          end
        end
      end
    end
    scope module: "messages" do
      resources :profiles, only: %i[show], as: :mention_profile
    end

    resource :inbox, only: %i[ show ] do
      member do
        get :mentions
        get :notifications
        get :messages
        get :bookmarks
        post :clear
      end
      scope path: "/paged", as: :paged do
        resources :mentions, only: %i[ index ], controller: 'inboxes/mentions'
        resources :notifications, only: %i[ index ], controller: 'inboxes/notifications'
        resources :messages, only: %i[ index ], controller: 'inboxes/messages'
        resources :bookmarks, only: %i[ index ], controller: 'inboxes/bookmarks'
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

    get "webmanifest"    => "pwa#manifest"
    get "service-worker" => "pwa#service_worker"

    get 'library' => 'library#show'

    get "up" => "rails/health#show", as: :rails_health_check
  end

  # New root route
  root to: "home#index"
end
