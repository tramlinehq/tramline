Rails.application.routes.draw do
  require "sidekiq/web"

  mount ActionCable.server => "/cable"

  authenticate :user, ->(u) { u.admin? || Rails.env.development? } do
    mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
    mount Flipper::UI.app(Flipper), at: "/flipper"
    mount Sidekiq::Web, at: "/sidekiq"
    mount PgHero::Engine, at: "/pghero"
  end

  devise_for :users,
             controllers: { registrations: "authentication/registrations", sessions: "authentication/sessions" },
             class_name: "Accounts::User"

  devise_scope :user do
    unauthenticated :user do
      root "authentication/sessions#new"
    end

    authenticated :user, ->(u) { u.admin? } do
      root "admin/settings#index", as: :authenticated_admin_root
    end

    authenticated :user do
      root "apps#index", as: :authenticated_root
    end
  end

  namespace :authentication do
    resources :invite_confirmations, only: %i[new create]
  end

  namespace :accounts do
    resources :organizations, only: [:index] do
      member do
        get :switch
      end

      resource :team, only: [:show]
      resources :invitations, only: %i[new create]
    end
  end

  resources :apps do
    resource :app_config, only: %i[edit update], path: :config
    resource :sign_off_groups, only: %i[edit update]

    resources :trains do
      member do
        patch :deactivate
      end

      resources :steps, only: %i[new create edit update], shallow: true do
        resource :sign_off do
          collection do
            post :approve
            post :reject
            delete :revert
          end
        end

        resources :deployments, shallow: true do
          member do
            post :start
          end

          resources :deployment_runs, shallow: true do
            member do
              patch :promote
            end
          end
        end
      end

      resources :releases, only: %i[show create destroy], shallow: true do
        resources :step_runs, shallow: false, module: "releases" do
          member do
            post :start
          end
        end

        member do
          get :timeline
          post :post_release
        end

        collection do
          get :live_release
        end
      end
    end

    resources :integrations, only: %i[index create] do
      member do
        get :build_artifact_channels
      end

      collection do
        get :connect, to: "integrations#connect", as: :connect
        resource :google_play_store, only: [:create],
                 controller: "integrations/google_play_store",
                 as: :google_play_store_integration
      end
    end
  end

  namespace :admin do
    resource :settings, only: [:index]
  end

  scope :github do
    get :callback, controller: "integration_listeners/github", as: :github_callback
    post "/events/:train_id", to: "integration_listeners/github#events", as: :github_events
  end

  scope :gitlab do
    get :callback, controller: "integration_listeners/gitlab", as: :gitlab_callback
    post "/events/:train_id", to: "integration_listeners/gitlab#events", as: :gitlab_events
  end

  scope :slack do
    get :callback, controller: "integration_listeners/slack", as: :slack_callback
  end
end
