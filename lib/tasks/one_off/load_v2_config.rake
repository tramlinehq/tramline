namespace :one_off do
  desc "Populate the config for all trains with v2 enabled"
  task load_v2_config: [:destructive, :environment] do |_, _args|
    trains = Train.all.filter { |train| train.product_v2? }
    trains.each do |train|
      puts "Populating config for train: #{train.name}"
      train.release_platforms.each do |release_platform|
        populate_config(release_platform)
      end
    end

    puts "Done!"
  end
end

def submission_type(deployment)
  return unless deployment&.integration

  case deployment.integration.providable_type
  when "GooglePlayStoreIntegration"
    "PlayStoreSubmission"
  when "AppStoreIntegration"
    deployment.production_channel? ? "AppStoreSubmission" : "TestFlightSubmission"
  when "GoogleFirebaseIntegration"
    "GoogleFirebaseSubmission"
  else
    raise "Unknown deployment integration type: #{deployment.integration.providable_type}"
  end
end

def populate_config(release_platform)
  config = {}
  review_step = release_platform.steps.review.first
  release_step = release_platform.release_step
  internal_workflow_config = nil

  if review_step
    internal_workflow_config = {
      kind: "internal",
      id: review_step.workflow_id,
      name: review_step.workflow_name,
      artifact_name_pattern: review_step.build_artifact_name_pattern
    }
  end

  rc_workflow_config = {
    kind: "release_candidate",
    id: release_step.workflow_id,
    name: release_step.workflow_name,
    artifact_name_pattern: release_step.build_artifact_name_pattern
  }

  config[:workflows] = {
    internal: internal_workflow_config,
    release_candidate: rc_workflow_config
  }

  if review_step
    config[:internal_release] = {
      auto_promote: true,
      submissions: review_step.deployments.each_with_index.map do |deployment, index|
        {number: index + 1,
         submission_type: submission_type(deployment),
         submission_config: deployment.build_artifact_channel,
         rollout_config: {enabled: false},
         auto_promote: true}
      end.compact
    }
  end

  config[:beta_release] = {
    auto_promote: false,
    submissions: release_step.deployments.each_with_index.map do |deployment, index|
      next if deployment.production_channel?

      {number: index + 1,
       submission_type: submission_type(deployment),
       submission_config: deployment.build_artifact_channel,
       rollout_config: {enabled: false},
       auto_promote: index.zero? ? true : release_step.auto_deploy?}
    end.compact
  }

  production_deployment = release_step.deployments.find { |deployment| deployment.production_channel? }
  if production_deployment
    config[:production_release] = {
      auto_promote: false,
      submissions: [
        {
          number: 1,
          submission_type: submission_type(production_deployment),
          submission_config: production_deployment.build_artifact_channel,
          rollout_config: {enabled: production_deployment.is_staged_rollout,
                           stages: production_deployment.staged_rollout_config},
          auto_promote: false
        }
      ]
    }
  end

  release_platform.config = config
  release_platform.save!
end
