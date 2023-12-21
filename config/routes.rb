VERSION_NAME_REGEX = /\d+\.\d+(\.\d+)?(-\w+)?/

Rails.application.routes.draw do
  require "sidekiq/web"
  require "sidekiq/cron/web"

  mount ActionCable.server => "/cable"
  mount Easymon::Engine => "/up"

  authenticate :user, ->(u) { u.admin? || Rails.env.development? } do
    mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
    mount Flipper::UI.app(Flipper), at: "/flipper"
    mount Sidekiq::Web, at: "/sidekiq"
    mount PgHero::Engine, at: "/pghero"
  end

  devise_for :users,
    controllers: {registrations: "authentication/registrations", sessions: "authentication/sessions", confirmations: "authentication/confirmations"},
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
    resources :organizations, only: [:edit, :index] do
      member do
        get :switch
      end

      resource :team, only: [:show]
      resources :invitations, only: %i[new create]
    end
  end

  resources :apps do
    resource :app_config, only: %i[edit update], path: :config do
      resources :app_variants, only: %i[create update]
    end

    member do
      get :all_builds
      post :refresh_external
    end

    resources :trains, only: %i[new create edit update show destroy] do
      member do
        get :steps
        post :clone, to: "trains#replicate"
        patch :activate
        patch :deactivate
      end

      resources :notification_settings, only: %i[index update]

      resources :release_platforms, only: [], path: :platforms, as: :platforms do
        resources :steps, only: %i[new create edit update]
      end

      resources :releases, only: %i[show create destroy index], shallow: true do
        resources :commits, only: [], shallow: false do
          member do
            post :apply
          end
        end

        resources :build_queues, only: [], shallow: false do
          member do
            post :apply
          end
        end

        resources :step_runs, only: [], shallow: false do
          member do
            post :start
            patch :retry_ci_workflow
            patch :sync_store_status
          end

          resources :deployments, only: [] do
            member do
              post :start
            end

            resources :deployment_runs, only: [], shallow: true do
              member do
                patch :submit_for_review
                patch :start_release
                patch :prepare_release
              end

              resource :staged_rollout, only: [] do
                member do
                  patch :increase
                  patch :halt
                  patch :fully_release
                  patch :pause
                  patch :resume
                end
              end
            end
          end
        end

        resource :release_metadatum, only: %i[edit update], path: :metadata

        collection do
          get :live_release
          get :ongoing_release
          get :upcoming_release
          get :hotfix_release
        end

        member do
          get :timeline
          post :post_release
          post :finish_release
        end
      end
    end

    resources :integrations, only: %i[index create] do
      collection do
        get :connect, to: "integrations#connect", as: :connect

        resource :google_play_store, only: [:create],
          controller: "integrations/google_play_store",
          as: :google_play_store_integration

        resource :bitrise, only: [:create],
          controller: "integrations/bitrise",
          as: :bitrise_integration

        resource :bugsnag, only: [:create],
          controller: "integrations/bugsnag",
          as: :bugsnag_integration

        resource :app_store, only: [:create],
          controller: "integrations/app_store",
          as: :appstore_integration

        resource :google_firebase, only: [:create],
          controller: "integrations/google_firebase",
          as: :google_firebase_integration
      end

      resources :slack, only: [],
        controller: "integrations/slack",
        as: :slack_integration do
        member do
          post :refresh_channels
        end
      end

      resources :google_firebase, only: [],
        controller: "integrations/google_firebase",
        as: :google_firebase_integration do
        member do
          post :refresh_channels
        end
      end
    end

    get "/integrations/build_artifact_channels", to: "integrations#build_artifact_channels"
  end

  namespace :admin do
    resource :settings, only: [:index]
  end

  namespace :api, defaults: {format: "json"} do
    namespace :v1, path: "v1" do
      get "ping", to: "pings#show"
      get "releases/*release_id", to: "releases#show"
      get "apps/*app_id", to: "apps#show"
      patch "apps/:app_id/builds/:version_name/:version_code/external_metadata", to: "builds#external_metadata", constraints: {version_name: VERSION_NAME_REGEX}
    end
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

  get "/rails/active_storage/blobs/redirect/:signed_id/*filename", to: "authorized_blob_redirect#show", as: "blob_redirect"
  match "/", via: %i[post put patch delete], to: "application#raise_not_found", format: false
  match "*unmatched_route", via: :all, to: "application#raise_not_found", format: false,
    constraints: lambda { |req| req.path.exclude? "rails/active_storage" }
end
