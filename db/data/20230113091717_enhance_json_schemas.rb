class EnhanceJsonSchemas < ActiveRecord::Migration[7.0]
  def up
    return unless Rails.env.production?

    ActiveRecord::Base.transaction do
      app_configs
      steps
      deployments
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def app_configs
    AppConfig.all.each do |config|
      repo, notifs, project = config.values_at(:code_repository, :notification_channel, :project_id)
      repo_map = _init_map([:id, :name, :namespace, :full_name, :description, :repo_url, :avatar_url])
      notifs_map = _init_map([:id, :name, :description, :is_private, :member_count])
      project_map = _init_map([:id, :name, :provider, :repo_url, :avatar_url])

      if repo.present?
        id = repo.keys.first
        name = repo.values.first
        namespace, only_name = name.split("/")

        repo_map["id"] = id.to_s
        repo_map["name"] = only_name.to_s
        repo_map["namespace"] = namespace.to_s
        repo_map["full_name"] = name.to_s

        config.code_repository = repo_map
      end

      if notifs.present?
        id = notifs.keys.first
        name = notifs.values.first

        notifs_map["id"] = id.to_s
        notifs_map["name"] = name.to_s
        notifs_map["description"] = ""
        notifs_map["is_private"] = false
        notifs_map["member_count"] = nil

        config.notification_channel = notifs_map
      end

      if project.present?
        id = project.keys.first
        name = project.values.first

        project_map["id"] = id.to_s
        project_map["name"] = name.to_s

        config.project_id = project_map
      end

      config.save!
    end
  end

  def steps
    Releases::Step.all.each do |step|
      ci_cd = step[:ci_cd_channel]
      ci_cd_map = _init_map([:id, :name])

      if ci_cd.present?
        id = ci_cd.keys.first
        name = ci_cd.values.first

        ci_cd_map["id"] = id.to_s
        ci_cd_map["name"] = name.to_s

        step.ci_cd_channel = ci_cd_map
        step.save!
      end
    end
  end

  def deployments
    Deployment.all.each do |deployment|
      build_artifact = deployment[:build_artifact_channel]

      if build_artifact.present?
        if deployment.integration.nil?
          build_artifact_map = _init_map([:id, :name])
          id = "external"
          name = "External"

          build_artifact_map["id"] = id.to_s
          build_artifact_map["name"] = name.to_s

          deployment.build_artifact_channel = build_artifact_map
        elsif deployment.integration.providable_type.eql?("SlackIntegration")
          build_artifact_map = _init_map([:id, :name])
          id = build_artifact.keys.first
          name = build_artifact.values.first

          build_artifact_map["id"] = id.to_s
          build_artifact_map["name"] = name.to_s

          deployment.build_artifact_channel = build_artifact_map
        elsif deployment.integration.providable_type.eql?("GooglePlayStoreIntegration")
          build_artifact_map = _init_map([:id, :name])

          # id is present as value and name is present as key (inverted from the others)
          id = build_artifact.values.first
          name = build_artifact.keys.first

          build_artifact_map["id"] = id.to_s
          build_artifact_map["name"] = name.to_s

          deployment.build_artifact_channel = build_artifact_map
        end

        deployment.save!
      end
    end
  end

  def _init_map(keys)
    keys.product([""]).to_h.with_indifferent_access
  end
end
