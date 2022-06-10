Rails.application.routes.draw do
  require "sidekiq/web"
  require "sidekiq-scheduler/web"

  mount ActionCable.server => "/cable"

  authenticate :user, ->(u) { u.admin? } do
    mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
    mount Flipper::UI.app(Flipper), at: "/flipper"
    mount Sidekiq::Web, at: "/sidekiq"
  end

  devise_for :users,
             controllers: { registrations: "authentication/registrations",
                            sessions: "authentication/sessions" },
             class_name: "Accounts::User"

  devise_scope :user do
    unauthenticated :user do
      root "authentication/sessions#new"
    end

    authenticated :user do
      root "accounts/apps#index", as: :authenticated_root
    end
  end

  namespace :authentication do
    resources :invite_confirmations, only: [:new, :create]
  end

  namespace :accounts do
    resources :organizations do
      member do
        get :switch
      end

      resource :team
      resources :invitations

      resources :apps do
        resource :app_config, only: [:edit, :update], path: :config
        namespace :releases do
          resources :trains do
            member do
              patch :deactivate
            end
            resources :steps
          end
        end

        resources :integrations do
          collection do
            get :connect, to: "integrations#connect", as: :connect
            resource :google_play_store, only: [:create],
                                         controller: "integrations/google_play_store", as: :google_play_store_integration
          end
        end
      end
    end
  end

  namespace :admin do
    resource :settings
  end

  scope :github do
    post "/events/:train_id", to: "github#events", as: :github_events
    get :callback, controller: "integration_listeners/github", as: :github_callback
  end

  scope :slack do
    get :callback, controller: "integration_listeners/slack", as: :slack_callback
  end
end
