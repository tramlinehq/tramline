VERSION_NAME_REGEX = /\d+\.\d+(\.\d+)?(-\w+)?/ unless defined? VERSION_NAME_REGEX

Rails.application.routes.draw do
  require "sidekiq/web"
  require "sidekiq/cron/web"

  mount ActionCable.server => "/cable"
  mount Easymon::Engine => "/up"
  # get "up" => "rails/health#show", as: :rails_health_check

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
    resources :invite_confirmations, only: %i[new create], controller: "email/invite_confirmations"
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

    resource :user, only: [:edit, :update] do
      member do
        patch :update_user_role
      end
    end
  end

  resources :apps do
    resource :app_config, only: %i[edit update], path: :config do
      resources :app_variants, only: %i[index edit create update destroy]
    end

    member do
      get :all_builds
      post :refresh_external
    end

    resources :trains, only: %i[new create edit update destroy] do
      member do
        get :rules
        patch :activate
        patch :deactivate
      end

      resource :release_index, only: %i[edit update]
      resources :notification_settings, only: %i[index update edit]

      resources :release_platforms, path: :platforms, as: :platforms do
        resources :release_health_rules, path: :rules
        resource :release_platform_configs, only: %i[edit update], path: :submissions, as: :submission_config, controller: "config/release_platforms"
      end

      resources :releases, only: %i[show create destroy index update], shallow: true do
        member do
          get :overview
          get :changeset_tracking
          get :regression_testing
          get :soak
          get :wrap_up_automations
          patch :override_approvals
          post :copy_approvals
        end

        resources :approval_items, only: %i[index create update destroy], shallow: false

        get :edit, to: "release_metadata#index", path: :metadata, as: :metadata_edit
        patch :update, to: "release_metadata#update_all", path: :metadata, as: :metadata_update
        get :index, to: "beta_releases#index", as: :release_candidates, path: :release_candidates
        get :index, to: "store_submissions#index", path: :store_submission, as: :store_submissions
        get :index, to: "store_rollouts#index", path: :rollout, as: :store_rollouts
        get :index, to: "internal_releases#index", as: :internal_builds, path: :internal_builds

        resources :build_queues, only: [], shallow: false do
          member do
            post :apply
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
      member do
        post :reuse
      end
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

        resource :crashlytics, only: [:create],
          controller: "integrations/crashlytics",
          as: :crashlytics_integration
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
    member do
      post :pre_prod_internal, to: "internal_releases#create"
      post :pre_prod_beta, to: "beta_releases#create"
    end

    post :production, to: "production_releases#create"

    resources :pre_prod_releases, shallow: true, only: [] do
      member do
        get :changes_since_previous
      end
    end

    resources :production_releases, shallow: true, only: [] do
      member do
        get :changes_since_previous
      end
    end
  end

  resources :store_rollouts, only: [], shallow: false, path: :rollouts do
    member do
      patch :start
      patch :increase
      patch :pause
      patch :resume
      patch :halt
      patch :fully_release
    end
  end

  resources :store_submissions, only: [:update], shallow: false, path: :store_submissions do
    member do
      patch :retry
      patch :trigger
      patch :submit_for_review
      patch :prepare
      patch :cancel
      patch :remove_from_review
      patch :fully_release_previous_rollout
    end
  end

  if Rails.env.development?
    patch "/store_submissions/:id/mock_reject", to: "store_submissions#mock_reject_for_app_store", as: :mock_reject_for_app_store
    patch "/store_submissions/:id/mock_approve", to: "store_submissions#mock_approve_for_app_store", as: :mock_approve_for_app_store
  end

  resources :workflow_runs, only: [] do
    member do
      patch :retry
      patch :trigger
      patch :fetch_status
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

  scope :bitbucket do
    get :callback, controller: "integration_listeners/bitbucket", as: :bitbucket_callback
    post "/events/:train_id", to: "integration_listeners/bitbucket#events", as: :bitbucket_events
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
