class OnboardingToTrainConverter
  attr_reader :onboarding_state, :app

  def initialize(onboarding_state)
    @onboarding_state = onboarding_state
    @app = onboarding_state.app
  end

  def convert!
    return false unless onboarding_state.ready_for_completion?

    ActiveRecord::Base.transaction do
      train = create_train
      create_release_platform(train) if app.cross_platform? || app.ios?
      create_release_platform(train, platform: :android) if app.cross_platform? || app.android?

      true
    end
  end

  private

  def create_train
    Train.create!(
      app: app,
      name: "Release Train",
      platform: app.platform,
      active: true,
      versioning_strategy: onboarding_state.version_strategy || "semantic",
      source_branch: onboarding_state.source_branch || "main",
      branching_strategy: map_branching_strategy,
      branch_name_format: onboarding_state.branch_naming_format || "release/{version}",
      tag_format: onboarding_state.tag_format,
      tag_all_store_releases: onboarding_state.tag_all_releases,
      auto_deploy: onboarding_state.auto_deployment,
      compact_build_notes: onboarding_state.copy_changelog
    )
  end

  def create_release_platform(train, platform: :ios)
    platform_sym = platform.to_sym

    release_platform = ReleasePlatform.create!(
      train: train,
      platform: platform_sym
    )

    # Set up CI/CD step
    if onboarding_state.ci_cd_workflow.present?
      Config::ReleaseStep.create!(
        release_platform: release_platform,
        name: "Build",
        kind: "ci_cd",
        ci_cd_channel: {
          provider: onboarding_state.ci_cd_provider,
          workflow: onboarding_state.ci_cd_workflow,
          branch_pattern: onboarding_state.ci_cd_branch_pattern
        }
      )
    end

    # Set up RC step for iOS (TestFlight) if enabled
    if platform_sym == :ios && onboarding_state.rc_submission_enabled &&
        onboarding_state.rc_submission_provider == "testflight"
      test_flight_config = app.integrations.app_store_integrations.first

      if test_flight_config
        Config::ReleaseStep.create!(
          release_platform: release_platform,
          name: "TestFlight Distribution",
          kind: "beta_distribution"
        )
      end
    end

    # Set up RC step for Android (Firebase) if enabled
    if platform_sym == :android && onboarding_state.rc_submission_enabled &&
        onboarding_state.rc_submission_provider == "firebase"
      firebase_config = app.integrations.google_firebase_integrations.first

      if firebase_config
        Config::ReleaseStep.create!(
          release_platform: release_platform,
          name: "Firebase Distribution",
          kind: "beta_distribution"
        )
      end
    end

    # Set up Store Distribution step for Android
    if platform_sym == :android && onboarding_state.production_submission_enabled &&
        onboarding_state.production_submission_provider == "google_play_store"
      play_store_config = app.integrations.google_play_store_integrations.first

      if play_store_config
        Config::ReleaseStep.create!(
          release_platform: release_platform,
          name: "Play Store Distribution",
          kind: "store_distribution"
        )
      end
    end

    # Set up Store Distribution step for iOS
    if platform_sym == :ios && onboarding_state.production_submission_enabled &&
        onboarding_state.production_submission_provider == "app_store"
      app_store_config = app.integrations.app_store_integrations.first

      if app_store_config
        Config::ReleaseStep.create!(
          release_platform: release_platform,
          name: "App Store Distribution",
          kind: "store_distribution"
        )
      end
    end

    release_platform
  end

  def map_branching_strategy
    case onboarding_state.branching_strategy
    when "gitflow"
      "gitflow"
    when "github_flow"
      "trunk_based"
    when "release_branches"
      "release_branch"
    else
      "trunk_based"
    end
  end
end
