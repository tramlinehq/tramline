namespace :one_off do
  desc "Populate the config for all trains with v2 enabled"
  task :load_v2_data, %i[train_slug] => [:destructive, :environment] do |_, args|
    train_slug = args[:train_slug].to_s
    abort "Train ID not found!" if train_slug.blank?
    train = Train.find_by(slug: train_slug)
    abort "Train not found!" unless train

    puts "Populating config for train: #{train.name}"
    train.release_platforms.each do |release_platform|
      if release_platform.platform_config.present?
        puts "Skipping #{train.name} platform #{release_platform.platform} as it already has a config"
        next
      end
      populate_config(release_platform)
    end

    populate_v2_models_for_train(train)
  end
end

def populate_v2_models_for_train(train)
  puts "Moving data over from the releases of the train to the new models"
  ActiveRecord::Base.transaction do
    train.releases.where.not(is_v2: true).find_each do |release|
      populate_v2_models(release)
    end
  end

  train.releases.finished.each do |release|
    release.release_platform_runs.each do |release_platform_run|
      Queries::PlatformBreakdown.warm(release_platform_run.id)
    end
    Queries::ReleaseBreakdown.warm(release.id)
  end

  Queries::DevopsReport.warm(train)
end

def populate_v2_models(release)
  release.update!(is_v2: true)
  release.release_platform_runs.each do |prun|
    prun.update!(config: prun.release_platform.platform_config.as_json)

    raise "Config not loaded" if prun.config.blank?
    puts "Config loaded for #{prun.release_version} - #{prun.platform} as #{prun.config.inspect}"

    # review steps
    raise "More than one review step" if prun.release_platform.steps.review.size > 1
    convert_review_step!(prun)

    # release step
    raise "No release step" if prun.release_platform.release_step.blank?
    convert_release_step!(prun)
  end
end

def convert_review_step!(release_platform_run)
  review_step = release_platform_run.step_runs.detect { |step_run| step_run.step.review? }&.step
  return if review_step.blank?

  review_runs = release_platform_run.step_runs_for(review_step).order(scheduled_at: :asc).to_a
  review_step_run = review_runs.shift
  previous = nil
  idx = 0
  size = review_runs.size

  while review_step_run.present?
    is_latest = idx == size - 1
    pre_prod_release = create_pre_prod_release!(release_platform_run, review_step_run, previous, idx, is_latest, "internal")
    previous = pre_prod_release
    review_step_run = review_runs.shift
    idx += 1
  end
end

def convert_release_step!(prun)
  release_step = prun.step_runs.detect { |step_run| step_run.step.release? }&.step
  return if release_step.blank?
  release_step_runs = prun.step_runs_for(release_step).order(scheduled_at: :asc).to_a
  release_step_run = release_step_runs.shift
  previous_pre_prod_release = nil
  previous_production_release = nil
  idx = 0
  size = release_step_runs.size
  production_release_config = prun.conf.production_release.as_json

  while release_step_run.present?
    is_latest = idx == size - 1
    pre_prod_release = create_pre_prod_release!(prun, release_step_run, previous_pre_prod_release, idx, is_latest, "release_candidate")
    release_step_run.deployment_runs.filter(&:production_channel?).each do |drun|
      production_release = prun.production_releases.create!(
        config: production_release_config,
        build: pre_prod_release.build,
        status: compute_production_release_status(release_step_run, is_latest),
        previous: previous_production_release,
        created_at: release_step_run.created_at,
        updated_at: release_step_run.updated_at
      )

      config_json = {
        number: 1,
        submission_type: submission_type(drun.deployment),
        submission_config: drun.deployment.build_artifact_channel,
        auto_promote: false,
        integrable_id: release_step_run.app.id,
        integrable_type: "App",
        rollout_config: {enabled: drun.deployment.staged_rollout?, stages: drun.deployment.staged_rollout_config}
      }.with_indifferent_access
      submission_config = Config::Submission.from_json(config_json)

      submission = submission_config.submission_class.create!(
        parent_release: production_release,
        release_platform_run: prun,
        build: pre_prod_release.build,
        sequence_number: submission_config.number,
        config: submission_config.as_json,
        status: drun.failed? ? "failed" : success_state(submission_config.submission_class),
        approved_at: drun.review_failed? ? nil : drun.external_release&.reviewed_at,
        failure_reason: drun.failure_reason,
        prepared_at: drun.submitted_at,
        rejected_at: drun.review_failed? ? drun.external_release&.reviewed_at : nil,
        submitted_at: drun.submitted_at || drun.created_at,
        store_link: drun.external_link,
        store_release: drun.external_release&.attributes,
        store_status: drun.external_release&.status,
        created_at: drun.created_at,
        updated_at: drun.updated_at
      )

      create_passports(submission, drun)

      if drun.staged_rollout.present?
        if submission.is_a?(PlayStoreSubmission)
          submission.create_play_store_rollout!(
            release_platform_run: prun,
            current_stage: drun.staged_rollout&.current_stage || 0,
            config: submission_config.rollout_stages.presence || [],
            is_staged_rollout: submission_config.rollout_enabled,
            status: compute_store_rollout_status(drun.staged_rollout),
            created_at: drun.staged_rollout.created_at,
            updated_at: drun.staged_rollout.updated_at
          )
          create_passports(submission.play_store_rollout, drun.staged_rollout)
        elsif submission.is_a?(AppStoreSubmission)
          submission.create_app_store_rollout!(
            release_platform_run: prun,
            current_stage: drun.staged_rollout&.current_stage || 0,
            config: submission_config.rollout_stages.presence || [],
            is_staged_rollout: submission_config.rollout_enabled,
            status: compute_store_rollout_status(drun.staged_rollout),
            created_at: drun.staged_rollout.created_at,
            updated_at: drun.staged_rollout.updated_at
          )
          create_passports(submission.app_store_rollout, drun.staged_rollout)
        end
      elsif drun.released?
        create_non_staged_rollout(submission, drun, prun)
      end

      # rubocop:disable Rails/SkipsModelValidations
      drun.release_health_events.update_all(production_release_id: production_release.id)
      drun.release_health_metrics.update_all(production_release_id: production_release.id)
      # rubocop:enable Rails/SkipsModelValidations

      previous_pre_prod_release = pre_prod_release
      previous_production_release = production_release
      idx += 1
    end

    release_step_run = release_step_runs.shift
  end
end

def create_pre_prod_release!(release_platform_run, step_run, previous, idx, is_latest, kind)
  commit = step_run.commit
  status = compute_pre_prod_release_status(step_run, is_latest)
  tester_notes = step_run.build_notes
  pre_prod_release_attrs = {
    commit:,
    status:,
    previous:,
    tester_notes:,
    created_at: step_run.created_at,
    updated_at: step_run.updated_at,
    in_data_migration_mode: true
  }

  if kind == "internal"
    config = release_platform_run.conf.internal_release
    workflow_config = release_platform_run.conf.pick_internal_workflow
    pre_prod_release = release_platform_run.internal_releases.create!(**pre_prod_release_attrs.merge(config:))
  else
    config = release_platform_run.conf.beta_release
    pre_prod_release = release_platform_run.beta_releases.create!(**pre_prod_release_attrs.merge(config:))
    workflow_config = release_platform_run.conf.release_candidate_workflow
  end

  workflow_run = WorkflowRun.create!(
    release_platform_run:,
    commit:,
    triggering_release: pre_prod_release,
    workflow_config: workflow_config.as_json,
    kind: workflow_config.kind,
    status: compute_workflow_run_status(step_run),
    artifacts_url: nil,
    external_number: step_run.commit.short_sha,
    external_url: step_run.ci_link,
    external_id: step_run.ci_ref,
    started_at: step_run.passports.find_by(reason: :ci_triggered)&.event_timestamp,
    finished_at: step_run.passports.find_by(reason: :ci_finished)&.event_timestamp,
    created_at: step_run.passports.find_by(reason: :ci_triggered)&.event_timestamp || step_run.created_at,
    updated_at: step_run.updated_at
  )

  create_passports(workflow_run, step_run)

  build = workflow_run.create_build!(
    release_platform_run:,
    workflow_run:,
    commit:,
    build_number: step_run.build_number,
    version_name: step_run.basic_build_version,
    sequence_number: idx,
    size_in_bytes: step_run.build_size,
    external_id: nil,
    slack_file_id: step_run.slack_file_id,
    generated_at: step_run.passports.find_by(reason: :ci_finished)&.event_timestamp,
    created_at: step_run.passports.find_by(reason: [:build_available, :build_found_in_store])&.event_timestamp,
    updated_at: step_run.updated_at
  )

  step_run.build_artifact&.update!(build_id: build.id)
  step_run.external_build&.update!(build_id: build.id)

  step_run.deployment_runs.reject(&:production_channel?).each_with_index do |deployment_run, _|
    create_pre_prod_submission(release_platform_run, step_run, deployment_run, pre_prod_release, build)
  end

  create_passports(pre_prod_release, step_run)

  update_release_platform_run_config(release_platform_run, kind)

  pre_prod_release
end

def create_passports(new_model, old_model)
  new_model.passports.delete_all
  old_model.passports.find_each do |passport|
    passport_mapping = PASSPORT_MAPPINGS[old_model.class.name][passport.reason.to_s]
    next if passport_mapping.blank?
    class_name = passport_mapping[:stampable_type]
    reason = passport_mapping[:stampable_reason]
    raise "Invalid passport mapping" if reason.blank?
    raise "Invalid passport mapping" if class_name.blank?
    next unless new_model.is_a? class_name.constantize
    next if new_model.class::STAMPABLE_REASONS.exclude?(reason)
    Passport.create!(
      stampable: new_model,
      reason:,
      kind: passport.kind,
      message: passport.message,
      metadata: passport.metadata,
      event_timestamp: passport.event_timestamp,
      automatic: passport.automatic?,
      author_id: passport.author_id,
      author_metadata: passport.author_metadata,
      created_at: passport.created_at,
      updated_at: passport.updated_at
    )
  end
end

def update_release_platform_run_config(release_platform_run, kind)
  releases = (kind == "internal") ? release_platform_run.internal_releases : release_platform_run.beta_releases
  config_key = (kind == "internal") ? "internal_release" : "beta_release"
  if releases.where(status: :finished).first.present?
    config = release_platform_run.config
    config[config_key]["submissions"] = []
    releases.where(status: :finished).first.store_submissions.order(sequence_number: :asc).each do |submission|
      config[config_key]["submissions"] << submission.config
    end
    release_platform_run.config = config
    release_platform_run.save!
  end
end

def create_pre_prod_submission(release_platform_run, step_run, deployment_run, parent_release, build)
  config_json = {
    number: deployment_run.deployment.deployment_number,
    submission_type: submission_type(deployment_run.deployment),
    submission_config: deployment_run.deployment.build_artifact_channel,
    auto_promote: false,
    integrable_id: step_run.app.id,
    integrable_type: "App",
    rollout_config: {enabled: false, stages: []}
  }.with_indifferent_access
  config = Config::Submission.from_json(config_json)
  submission = config.submission_class.create!(
    parent_release:,
    release_platform_run:,
    build:,
    sequence_number: config.number,
    config: config.as_json,
    status: deployment_run.failed? ? "failed" : success_state(config.submission_class),
    approved_at: deployment_run.review_failed? ? nil : deployment_run.external_release&.reviewed_at,
    failure_reason: deployment_run.failure_reason,
    prepared_at: deployment_run.submitted_at,
    rejected_at: deployment_run.review_failed? ? deployment_run.external_release&.reviewed_at : nil,
    submitted_at: deployment_run.submitted_at || deployment_run.created_at,
    store_link: deployment_run.external_link,
    store_release: deployment_run.external_release&.attributes,
    store_status: deployment_run.external_release&.status,
    created_at: deployment_run.created_at,
    updated_at: deployment_run.updated_at,
    in_data_migration_mode: true
  )

  create_passports(submission, deployment_run)

  if submission.is_a?(PlayStoreSubmission) && deployment_run.released?
    create_non_staged_rollout(submission, deployment_run, release_platform_run)
  end
end

def create_non_staged_rollout(submission, deployment_run, release_platform_run)
  rollout_created = deployment_run.passports.find_by(reason: :released)&.event_timestamp || deployment_run.updated_at
  rollout = if submission.is_a?(PlayStoreSubmission)
    submission.create_play_store_rollout!(
      release_platform_run:,
      config: [],
      is_staged_rollout: false,
      status: "completed",
      created_at: rollout_created,
      updated_at: rollout_created
    )
  elsif submission.is_a?(AppStoreSubmission)
    submission.create_play_store_rollout!(
      release_platform_run:,
      config: [],
      is_staged_rollout: false,
      status: "completed",
      created_at: rollout_created,
      updated_at: rollout_created
    )
  else
    raise "Unknown submission type for a rollout - #{submission.class}"
  end

  data = rollout.send(:stamp_data)
  Passport.create!(
    stampable: rollout,
    reason: :completed,
    kind: :success,
    message: I18n.t("passport.#{rollout.class.name.underscore}.completed_html", **data),
    metadata: data,
    event_timestamp: rollout_created,
    automatic: true,
    author_id: nil,
    author_metadata: nil,
    created_at: rollout_created,
    updated_at: rollout_created
  )
end

def compute_store_rollout_status(staged_rollout)
  if staged_rollout.stopped?
    "halted"
  elsif staged_rollout.failed?
    "started"
  else
    staged_rollout.status
  end
end

def compute_production_release_status(step_run, is_latest)
  if step_run.success?
    "finished"
  elsif step_run.deployment_started? && is_latest
    "active"
  elsif step_run.active? && is_latest
    "inflight"
  else
    "stale"
  end
end

def compute_pre_prod_release_status(step_run, is_latest)
  if step_run.success?
    "finished"
  elsif step_run.failed?
    "failed"
  elsif step_run.deployment_started? && is_latest
    "created"
  else
    "stale"
  end
end

def compute_workflow_run_status(step_run)
  if step_run.ci_workflow_failed?
    "failed"
  elsif step_run.ci_workflow_halted?
    "halted"
  elsif step_run.ci_workflow_unavailable?
    "unavailable"
  elsif step_run.ci_workflow_started?
    "started"
  elsif step_run.ci_workflow_triggered?
    "triggered"
  else
    "finished"
  end
end

def success_state(submission_type)
  case submission_type.to_s
  when "PlayStoreSubmission"
    "prepared"
  when "AppStoreSubmission"
    "approved"
  when "TestFlightSubmission"
    "finished"
  when "GoogleFirebaseSubmission"
    "finished"
  when "DeprecatedSubmission"
    "finished"
  else
    raise "Unknown submission type: #{submission_type}"
  end
end

PASSPORT_MAPPINGS = {
  "StepRun" => {
    "created" => {
      stampable_type: "PreProdRelease",
      stampable_reason: "created"
    },
    "ci_triggered" => {
      stampable_type: "WorkflowRun",
      stampable_reason: "triggered"
    },
    "ci_retriggered" => {
      stampable_type: "WorkflowRun",
      stampable_reason: "retried"
    },
    "ci_workflow_unavailable" => {
      stampable_type: "WorkflowRun",
      stampable_reason: "unavailable"
    },
    "ci_finished" => {
      stampable_type: "WorkflowRun",
      stampable_reason: "finished"
    },
    "ci_workflow_failed" => {
      stampable_type: "WorkflowRun",
      stampable_reason: "failed"
    },
    "ci_workflow_halted" => {
      stampable_type: "WorkflowRun",
      stampable_reason: "halted"
    },
    # "build_available" => {
    #   stampable_type: "PreProdRelease",
    #   stampable_reason: "build_available",
    # },
    # "build_unavailable" => {
    #   stampable_type: "PreProdRelease",
    #   stampable_reason: "build_unavailable",
    # },
    # "build_not_found_in_store" => {
    #   stampable_type: "PreProdRelease",
    #   stampable_reason: "build_not_found_in_store",
    # },
    # "build_found_in_store" => {
    #   stampable_type: "PreProdRelease",
    #   stampable_reason: "build_found_in_store",
    # },
    # "deployment_restarted" => {
    #   stampable_type: "PreProdRelease",
    #   stampable_reason: "deployment_restarted",
    # },
    "finished" => {
      stampable_type: "PreProdRelease",
      stampable_reason: "finished"
    }
    # "failed_with_action_required" => {
    #   stampable_type: "PreProdRelease",
    #   stampable_reason: "failed_with_action_required"
    # }
  },
  "DeploymentRun" =>
    {
      "created" => {
        stampable_type: "StoreSubmission",
        stampable_reason: "triggered"
      },
      "release_failed" => {
        stampable_type: "StoreSubmission",
        stampable_reason: "failed"
      },
      "prepare_release_failed" => {
        stampable_type: "StoreSubmission",
        stampable_reason: "failed"
      },
      "inflight_release_replaced" => {
        stampable_type: "StoreSubmission",
        stampable_reason: "prepared"
      },
      "submitted_for_review" => {
        stampable_type: "StoreSubmission",
        stampable_reason: "submitted_for_review"
      },
      "resubmitted_for_review" => {
        stampable_type: "StoreSubmission",
        stampable_reason: "resubmitted_for_review"
      },
      "review_approved" => {
        stampable_type: "StoreSubmission",
        stampable_reason: "review_approved"
      },
      # "release_started" => {
      #   stampable_type: "StoreRollout",
      #   stampable_reason: "release_started",
      # },
      "released" => {
        stampable_type: "StoreSubmission",
        stampable_reason: "finished"
      },
      "review_failed" => {
        stampable_type: "StoreSubmission",
        stampable_reason: "review_rejected"
      },
      "skipped" => {
        stampable_type: "StoreSubmission",
        stampable_reason: "finished_manually"
      }
    },
  "StagedRollout" =>
    {
      "started" => {
        stampable_type: "StoreRollout",
        stampable_reason: "started"
      },
      "paused" => {
        stampable_type: "StoreRollout",
        stampable_reason: "paused"
      },
      # "failed" => {
      #   stampable_type: "StoreRollout",
      #   stampable_reason: "dummy"
      # },
      # "failed_before_any_rollout" => {
      #   stampable_type: "StoreRollout",
      #   stampable_reason: "dummy"
      # },
      "resumed" => {
        stampable_type: "StoreRollout",
        stampable_reason: "resumed"
      },
      "increased" => {
        stampable_type: "StoreRollout",
        stampable_reason: "updated"
      },
      "completed" => {
        stampable_type: "StoreRollout",
        stampable_reason: "completed"
      },
      "halted" => {
        stampable_type: "StoreRollout",
        stampable_reason: "halted"
      },
      "fully_released" => {
        stampable_type: "StoreRollout",
        stampable_reason: "fully_released"
      }
    }
}.with_indifferent_access
