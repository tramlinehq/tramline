VERSION_NAME_REGEX = /\d+\.\d+(\.\d+)?(-\w+)?/ unless defined? VERSION_NAME_REGEX

Rails.application.routes.draw do
  require "sidekiq/web"
  require "sidekiq/cron/web"

  mount ActionCable.server => "/cable"
  mount Easymon::Engine => "/up"

  root "authentication/sessions#root"
  get "/admin", to: "admin/settings#index", as: :authenticated_admin_root

  authenticate :email_authentication, ->(u) { u.admin? || Rails.env.development? } do
    mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
    mount Flipper::UI.app(Flipper), at: "/flipper"
    mount Sidekiq::Web, at: "/sidekiq"
    mount PgHero::Engine, at: "/pghero"
  end

  devise_for :email_authentication,
    path: :email,
    controllers: {
      registrations: "authentication/email/registrations",
      sessions: "authentication/email/sessions",
      confirmations: "authentication/email/confirmations",
      passwords: "authentication/email/passwords"
    },
    class_name: "Accounts::EmailAuthentication"

  scope module: :authentication do
    namespace :sso do
      get "saml/redeem", to: "sessions#saml_redeem"
      get "sign_in", to: "sessions#new", as: :new_sso_session
      post "sign_in", to: "sessions#create", as: :create_sso_session
      get "sign_out", to: "sessions#destroy", as: :destroy_sso_session
    end
  end

  namespace :authentication do
    resources :invite_confirmations, only: %i[new create]
  end

  namespace :accounts do
    resources :organizations, only: [:edit] do
      member do
        get :switch
        get :teams
      end

      resources :teams, only: %i[create update destroy]
      resources :invitations, only: [:create]
    end

    resource :user, only: [:edit, :update]
  end

  resources :apps do
    resource :app_config, only: %i[edit update], path: :config do
      resources :app_variants, only: %i[create update index]
    end

    member do
      get :all_builds
      post :refresh_external
    end

    resources :trains, only: %i[new create edit update destroy] do
      member do
        get :steps
        get :rules
        patch :activate
        patch :deactivate
      end
      resource :release_index, only: %i[edit update]

      resources :notification_settings, only: %i[index update edit]

      resources :release_platforms, only: [], path: :platforms, as: :platforms do
        resources :steps, only: %i[new create update]
        resources :release_health_rules, path: :rules
      end

      resources :releases, only: %i[show create destroy index update], shallow: true do
        member do
          get :overview
          get :change_queue
          get :store_submissions
          get :internal_builds
          get :regression_testing
          get :release_candidates
          get :soak
        end

        resources :commits, only: [], shallow: false do
          member do
            post :apply
          end
        end

        get :edit, to: "store_rollouts#edit_all", path: :rollout, as: :staged_rollout_edit
        get :edit, to: "release_metadata#edit_all", path: :metadata, as: :metadata_edit
        patch :update, to: "release_metadata#update_all", path: :metadata, as: :metadata_update

        resources :release_platforms, shallow: false, only: [] do
          resources :release_metadata, only: %i[edit update]
        end

        resources :platforms, shallow: false, only: [] do
          resources :store_rollouts, only: [], path: :rollouts do
            member do
              patch :start
              patch :increase
              patch :pause
              patch :resume
              patch :halt
              patch :fully_release
            end
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

    resources :integrations, only: %i[index create destroy] do
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

  resources :release_platform_runs, path: :runs, as: :runs, only: [] do
    post :pre_prod_beta, to: "pre_prod_releases#create_beta"
    post :pre_prod_internal, to: "pre_prod_releases#create_internal"
    post :production, to: "production_releases#create"
  end

  resources :app_store_submissions, only: [:update] do
    member do
      patch :submit_for_review
      patch :prepare
      patch :cancel
      patch :remove_from_review
    end
  end

  if Rails.env.development?
    patch "/app_store_submissions/:id/mock_reject", to: "app_store_submissions#mock_reject_for_app_store", as: :mock_reject_for_app_store
    patch "/app_store_submissions/:id/mock_approve", to: "app_store_submissions#mock_approve_for_app_store", as: :mock_approve_for_app_store
  end

  resources :play_store_submissions, only: [:update] do
    member do
      patch :prepare
      patch :cancel
    end
  end

  resources :workflow_runs, only: [] do
    member do
      patch :retry
      patch :trigger
    end
  end

  resources :submissions, only: [] do
    member do
      patch :retry
      patch :trigger
    end
  end

  namespace :admin do
    resource :settings, only: [:index]
  end

  namespace :api, defaults: {format: "json"} do
    namespace :v1, path: "v1" do
      get "ping", to: "pings#show"
      get "releases/*release_id", to: "releases#show"
      get "apps/*app_id", to: "apps#show"
      patch "apps/:app_id/builds/:version_name/:version_code/external_metadata",
        to: "builds#external_metadata",
        constraints: {version_name: VERSION_NAME_REGEX}
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

  get "/rails/active_storage/blobs/redirect/:signed_id/*filename",
    to: "authorized_blob_redirect#show", as: "blob_redirect"
  match "/", via: %i[post put patch delete], to: "application#raise_not_found", format: false
  match "*unmatched_route", via: :all, to: "application#raise_not_found", format: false,
    constraints: lambda { |req| req.path.exclude? "rails/active_storage" }
end
