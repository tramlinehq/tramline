Rails.application.routes.draw do
  require 'sidekiq/web'
  require 'sidekiq-scheduler/web'

  mount ActionCable.server => '/cable'

  authenticate :user, ->(u) { u.admin? } do
    mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?
    mount Flipper::UI.app(Flipper), at: '/flipper'
    mount Sidekiq::Web, at: '/sidekiq'
  end

  devise_for :users,
             controllers: { registrations: 'authentication/registrations',
                            sessions: 'authentication/sessions' },
             class_name: 'Accounts::User'

  devise_scope :user do
    unauthenticated :user do
      root 'authentication/sessions#new'
    end

    authenticated :user do
      root 'apps#index', as: :authenticated_root
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

  resources :apps, only: %i[show index new create] do
    resource :app_config, only: %i[edit update], path: :config
    resource :sign_off_groups, only: %i[edit update]
    resources :trains do
      member do
        patch :deactivate
      end
      resources :steps, only: %i[new create edit update], shallow: true do
        resource :sign_off, only: %i[create destroy]
      end

      resources :releases, only: %i[show create destroy], shallow: true do
        resources :step_runs, only: [], shallow: false, module: 'releases' do
          member do
            post :start
            post :stop
          end
        end
        collection do
          get :live_release
        end
      end
    end
    resources :integrations, only: %i[index create] do
      collection do
        get :connect, to: 'integrations#connect', as: :connect
        resource :google_play_store, only: [:create],
                                     controller: 'integrations/google_play_store',
                                     as: :google_play_store_integration
      end
    end
  end

  namespace :admin do
    resource :settings, only: [:index]
  end

  scope :github do
    post '/events/:train_id', to: 'integration_listeners/github#events', as: :github_events
    get :callback, controller: 'integration_listeners/github', as: :github_callback
  end

  scope :slack do
    get :callback, controller: 'integration_listeners/slack', as: :slack_callback
  end
end
