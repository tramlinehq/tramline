module Sandboxable
  def sandbox_mode?
    Flipper.enabled?(:sandbox_mode) && Rails.env.development?
  end

  def mock_ci_trigger
    return unless sandbox_mode?
    update!(external_id: Faker::Number.number(digits: 8).to_s)
    build.update!(build_number: Faker::Number.number(digits: 4))
    initiated!
  end

  def mock_external_run
    return unless sandbox_mode?
    {
      ci_ref: Faker::Number.number(digits: 3).to_s,
      ci_link: "https://github.com/tramlinehq/ueno/actions",
      number: Faker::Number.number(digits: 8)
    }
  end

  def mock_finished_external_run
    return unless sandbox_mode?
    {
      status: "completed",
      conclusion: "success",
      run_started_at: Time.current,
      updated_at: Time.current,
      artifacts_url: "https://github.com/tramlinehq/ueno/actions/runs/10280894217/artifacts"
    }
  end

  def mock_attach_artifact
    return unless sandbox_mode?
    self.generated_at = workflow_run.finished_at
    self.size_in_bytes = 481516
    self.external_name = "ueno-0.1.0.apk"
    self.external_id = Faker::Alphanumeric.alphanumeric(number: 5)
    self.artifact = BuildArtifact.last
    save!
  end

  def mock_upload_to_firebase
    return unless sandbox_mode?
    prepare_and_update!(GoogleFirebaseIntegration::ReleaseInfo.new(
      {
        display_name: "dummy",
        firebaseConsoleUri: "google.com",
        build: 1,
        createTime: Time.current,
        status: "success",
        name: "dummy"
      }, GoogleFirebaseIntegration::ReleaseOpInfo::RELEASE_TRANSFORMATIONS
    ))
  end

  def mock_finish_firebase_release
    return unless sandbox_mode?
    finish!
  end

  def mock_build_present_in_play_store?
    return unless sandbox_mode?
    true
  end

  def mock_prepare_for_release_for_play_store!
    return unless sandbox_mode?
    update!(status: "preparing") unless preparing?
    finish_prepare!
  end

  def mock_start_play_store_rollout!
    return unless sandbox_mode?
    update_stage(4, finish_rollout: false)
    event_stamp!(reason: :started, kind: :notice, data: stamp_data)
    on_start!
  end

  def mock_complete_play_store_rollout!
    return unless sandbox_mode?
    complete!
    event_stamp!(reason: :completed, kind: :success, data: stamp_data)
  end

  def mock_start_app_store_rollout!
    return unless sandbox_mode?
    update_rollout(mocked_store_info("READY_FOR_SALE", "ACTIVE", 2))
    event_stamp!(reason: :started, kind: :notice, data: stamp_data)
  end

  def mock_find_build_in_testflight
    return unless sandbox_mode?
    true
  end

  def mock_start_release_in_testflight
    return unless sandbox_mode?
    update_store_info!(mocked_testflight_info("BETA_APPROVED"))
    finish!
  end

  def mock_trigger!
    return unless sandbox_mode?
    case type
    when "TestFlightSubmission"
      mock_start_release_in_testflight
    when "PlayStoreSubmission"
      mock_prepare_for_release_for_play_store!
    end
  end

  def mock_update_production_build!(build_id)
    return unless sandbox_mode?
    update!(build_id:)
    parent_release.update!(build_id:)
    return unless created? || cancelled?

    case type
    when "AppStoreSubmission"
      mock_prepare_for_release_for_app_store!
    when "PlayStoreSubmission"
      mock_prepare_for_release_for_play_store!
    end
  end

  def mock_prepare_for_release!
    return unless sandbox_mode?

    case type
    when "AppStoreSubmission"
      mock_prepare_for_release_for_app_store!
    when "PlayStoreSubmission"
      mock_prepare_for_release_for_play_store!
    end
  end

  def mock_prepare_for_release_for_app_store!
    return unless sandbox_mode?
    update_store_info!(mocked_store_info("PREPARE_FOR_SUBMISSION", "INACTIVE"))
    update!(status: "preparing")
    finish_prepare!
  end

  def mock_submit_for_review_for_app_store!
    return unless sandbox_mode?
    update_store_info!(mocked_store_info("IN_REVIEW", "INACTIVE"))
    update!(status: "submitting_for_review")
    submit_for_review!
  end

  def mock_cancel_review_for_app_store!
    return unless sandbox_mode?
    update_store_info!(mocked_store_info("DEVELOPER_REJECTED", "INACTIVE"))
    cancel!
  end

  def mock_approve_for_app_store!
    return unless sandbox_mode?
    update_store_info!(mocked_store_info("READY_FOR_SALE", "INACTIVE"))
    approve!
  end

  def mock_reject_for_app_store!
    return unless sandbox_mode?
    update_store_info!(mocked_store_info("REJECTED", "INACTIVE"))
    reject!
  end

  private

  def mocked_store_info(status, phased_release_status, phased_release_day = 0)
    AppStoreIntegration::AppStoreReleaseInfo.new(
      {
        external_id: Faker::Number.number(digits: 8).to_s,
        status:,
        build_number: build.build_number,
        name: build.version_name,
        added_at: Time.current,
        phased_release_day:,
        phased_release_status:,
        localizations: [{language: "en",
                         whats_new: Faker::Lorem.paragraph,
                         promo_text: Faker::Lorem.paragraph,
                         keywords: [Faker::Lorem.word, Faker::Lorem.word],
                         description: Faker::Lorem.paragraph}]
      }
    )
  end

  def mocked_testflight_info(status)
    AppStoreIntegration::TestFlightInfo.new(
      {
        external_id: Faker::Number.number(digits: 8).to_s,
        name: build.version_name,
        build_number: build.build_number,
        status: status,
        added_at: Time.current,
        external_link: "https://appstoreconnect.apple.com/"
      }
    )
  end
end
