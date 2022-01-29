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

  root "home#index"

  namespace :accounts do
    resources :organizations do
      resources :apps do
        member do
          post :create_release_branch
          post :create_pull_request
          post :run_workflow
        end

        namespace :releases do
          resources :trains do
            member do
              post :activate
            end
            resources :steps
          end
        end

        resources :integrations
      end
    end
  end

  namespace :admin do
    resource :settings
  end

  scope :github do
    get "/callback", to: "github#callback", as: "github_callback"
  end

  scope :slack do
    get "/callback", to: "slack#callback", as: "slack_callback"
  end
end
