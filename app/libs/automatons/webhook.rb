module Automatons
  class Webhook
    include Rails.application.routes.url_helpers

    attr_reader :train, :github_api

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(train:)
      @train = train
      @github_api = Installations::Github::Api.new(installation_id)
    end

    def dispatch!
      github_api.create_repo_webhook!(repo, url)
    end

    private

    def installation_id
      train
        .app
        .vcs_provider
        .installation_id
    end

    def repo
      train
        .app
        .config
        .code_repository
        .values
        .first
    end

    def url
      if Rails.env.development?
        github_events_url(host: ENV.fetch("WEBHOOK_HOST_NAME", nil), port: 3000, train_id: train.id)
      else
        github_events_url(host: ENV.fetch("HOST_NAME", nil), train_id: train.id, protocol: "https")
      end
    end
  end
end
