class BackFillWebhookIdsInTrain < ActiveRecord::Migration[7.0]
  def up
    return

    App.all.filter { |app| app.vcs_provider&.integration&.github_integration? }.each do |app|
      repo = app.config.code_repository_name
      webhooks = begin
        app.vcs_provider.installation.client.hooks(repo)
      rescue Octokit::ClientError, ArgumentError
        []
      end

      app.trains.where(status: "active", vcs_webhook_id: nil).each do |train|
        webhook = webhooks.find { |hook| hook[:config][:url].include?(train.id) }
        train.update(vcs_webhook_id: webhook[:id]) if webhook
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
