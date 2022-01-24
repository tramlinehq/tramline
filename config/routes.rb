Rails.application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  mount ActionCable.server => "/cable"
  mount Flipper::UI.app(Flipper) => "/flipper"

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
end
