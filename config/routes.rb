Rails.application.routes.draw do
  require "sidekiq/web"
  require "sidekiq-scheduler/web"

  mount ActionCable.server => "/cable"

  authenticate :user, lambda { |u| u.admin? } do
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

  namespace :accounts do
    resources :organizations do
      resources :apps do
        namespace :releases do
          resources :trains do
            member do
              patch :deactivate
            end
            resources :steps
          end
        end

        resources :integrations, except: [:create] do
          collection do
            get :connect, to: "integrations#connect", as: :connect
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
    get :callback, to: "github#callback", as: :github_callback
  end

  scope :slack do
    get :callback, to: "slack#callback", as: :slack_callback
  end
end
