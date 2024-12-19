require "rails_helper"

describe Deployments::AppStoreConnect::Release do
  describe ".kickoff!" do
    let(:test_flight_job) { Deployments::AppStoreConnect::TestFlightReleaseJob }
    let(:app_store_job) { Deployments::AppStoreConnect::PrepareForReleaseJob }

    before do
      allow(test_flight_job).to receive(:perform_async)
      allow(app_store_job).to receive(:perform_async)
    end

    it "does nothing if not allowed" do
      run = create(:deployment_run)
      expect(described_class.kickoff!(run)).to be_nil

      expect(app_store_job).not_to have_received(:perform_async)
      expect(test_flight_job).not_to have_received(:perform_async)
    end

    context "when production channel" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :started, deployment_traits: [:with_production_channel], step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }

      it "starts preparing the release" do
        described_class.kickoff!(run)

        expect(app_store_job).to have_received(:perform_async).with(run.id, false).once
      end
    end

    context "when not production channel" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :started, step_traits: [:review]) }
      let(:run) { factory_tree[:deployment_run] }

      it "starts adding to beta group when testflight" do
        described_class.kickoff!(run)

        expect(test_flight_job).to have_received(:perform_async).with(run.id).once
      end
    end
  end

  describe ".to_test_flight!" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if not allowed" do
      factory_tree = create_deployment_run_tree(:ios, :started, deployment_traits: [:with_production_channel], step_traits: [:release])
      run = factory_tree[:deployment_run]

      expect(described_class.to_test_flight!(run)).to be_nil

      expect(run.reload.started?).to be(true)
    end

    context "when successful" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :started, step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }

      before do
        allow(providable_dbl).to receive(:release_to_testflight).and_return(GitHub::Result.new)
      end

      it "adds build to beta group" do
        described_class.to_test_flight!(run)

        expect(providable_dbl).to have_received(:release_to_testflight).with(run.deployment_channel, run.build_number).once
      end

      it "marks the deployment run as submitted" do
        described_class.to_test_flight!(run)

        expect(run.reload.submitted_for_review?).to be(true)
      end
    end

    context "when failure" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :started, step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "beta_group", "code" => "not_found"}}) }

      before do
        allow(providable_dbl).to receive(:release_to_testflight).and_return(GitHub::Result.new { raise error })
      end

      it "marks the deployment run as failed when failure" do
        described_class.to_test_flight!(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        described_class.to_test_flight!(run)

        expect(run.reload.failure_reason).to eq("beta_group_not_found")
      end
    end
  end

  describe ".prepare_for_release!" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if not allowed" do
      run = create(:deployment_run, :preparing_release)

      expect(described_class.prepare_for_release!(run)).to be_nil

      expect(run.reload.preparing_release?).to be(true)
    end

    context "when successful" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :preparing_release, deployment_traits: [:with_production_channel], step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }
      let(:base_release_info) {
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: run.release_version,
          build_number: run.build_number,
          added_at: 1.day.ago
        }
      }
      let(:prepared_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "PREPARE_FOR_SUBMISSION")) }

      before do
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { prepared_release_info })
      end

      it "prepares the release" do
        described_class.prepare_for_release!(run)

        release_metadatum = run.release_platform_run.release_metadatum
        metadata = [{
          whats_new: release_metadatum.release_notes,
          promotional_text: release_metadatum.promo_text,
          locale: release_metadatum.locale
        }]
        expect(providable_dbl).to have_received(:prepare_release).with(run.build_number, run.release_version, false, metadata, false).once
      end

      it "marks the deployment run as prepared release" do
        described_class.prepare_for_release!(run)

        expect(run.reload.prepared_release?).to be(true)
      end

      it "prepares the release for staged deployment" do
        run = create_deployment_run_tree(:ios, :preparing_release, deployment_traits: [:with_phased_release], step_traits: [:release])[:deployment_run]
        described_class.prepare_for_release!(run)

        release_metadatum = run.release_platform_run.release_metadatum
        metadata = [{
          whats_new: release_metadatum.release_notes,
          promotional_text: release_metadatum.promo_text,
          locale: release_metadatum.locale
        }]
        expect(providable_dbl).to have_received(:prepare_release).with(run.build_number, run.release_version, true, metadata, false).once
      end

      it "prepares the release with force" do
        described_class.prepare_for_release!(run, force: true)

        release_metadatum = run.release_platform_run.release_metadatum
        metadata = [{
          whats_new: release_metadatum.release_notes,
          promotional_text: release_metadatum.promo_text,
          locale: release_metadatum.locale
        }]
        expect(providable_dbl).to have_received(:prepare_release).with(run.build_number, run.release_version, false, metadata, true).once
      end
    end

    context "when failure" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :preparing_release, deployment_traits: [:with_production_channel], step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}}) }

      before do
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { raise error })
      end

      it "marks the deployment run as failed when failure" do
        described_class.prepare_for_release!(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        described_class.prepare_for_release!(run)

        expect(run.reload.failure_reason).to eq("build_not_found")
      end
    end

    context "when retryable failure" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :preparing_release, deployment_traits: [:with_production_channel], step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "release", "code" => "release_already_prepared"}}) }

      before do
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { raise error })
      end

      it "marks the deployment run as failed to prepare release" do
        described_class.prepare_for_release!(run)

        expect(run.reload.failed_prepare_release?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        described_class.prepare_for_release!(run)

        expect(run.reload.failure_reason).to eq("release_already_exists")
      end
    end

    context "when invalid release" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :preparing_release, deployment_traits: [:with_phased_release], step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }
      let(:base_release_info) {
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: run.release_version,
          build_number: run.build_number,
          added_at: 1.day.ago,
          phased_release_status: "INACTIVE",
          phased_release_day: 0
        }
      }

      it "marks the deployment run as failed when invalid release due to version name mismatch" do
        invalid_release_info = AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(
          {status: "PREPARE_FOR_SUBMISSION",
           name: "invalid"}
        ))
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { invalid_release_info })
        described_class.prepare_for_release!(run)

        expect(run.reload.failed?).to be(true)
      end

      it "marks the deployment run as failed when invalid release due to build number mismatch" do
        invalid_release_info = AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(
          {status: "PREPARE_FOR_SUBMISSION",
           build_number: 123}
        ))
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { invalid_release_info })
        described_class.prepare_for_release!(run)

        expect(run.reload.failed?).to be(true)
      end

      it "marks the deployment run as failed when invalid release due to staged rollout mismatch" do
        invalid_release_info = AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(
          {status: "PREPARE_FOR_SUBMISSION",
           phased_release_status: nil}
        ))
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { invalid_release_info })
        described_class.prepare_for_release!(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        invalid_release_info = AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(
          {status: "PREPARE_FOR_SUBMISSION",
           build_number: 123}
        ))
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { invalid_release_info })
        described_class.prepare_for_release!(run)

        expect(run.reload.failure_reason).to eq("invalid_release")
      end
    end
  end

  describe ".submit_for_review!" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if not allowed" do
      allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new)
      run = create(:deployment_run, :prepared_release)

      expect(described_class.submit_for_review!(run)).to be_nil

      expect(providable_dbl).not_to have_received(:submit_release)
    end

    context "when successful" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :prepared_release, deployment_traits: [:with_production_channel], step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }

      before do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new)
      end

      it "submits the release" do
        described_class.submit_for_review!(run)

        expect(providable_dbl).to have_received(:submit_release).with(run.build_number, run.release_version).once
      end

      it "marks the deployment run as submitted" do
        described_class.submit_for_review!(run)

        expect(run.reload.submitted_for_review?).to be(true)
      end
    end

    context "when failure" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :started, deployment_traits: [:with_production_channel], step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}}) }
      let(:retryable_error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "release", "code" => "attachment_upload_in_progress"}}) }

      before do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new { raise error })
      end

      it "marks the deployment run as failed when failure" do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new { raise error })
        described_class.submit_for_review!(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new { raise error })
        described_class.submit_for_review!(run)

        expect(run.reload.failure_reason).to eq("build_not_found")
      end

      it "does not mark the deployment run as failed when the failure is retryable" do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new { raise retryable_error })
        described_class.submit_for_review!(run)

        expect(run.reload.failed?).to be(false)
        expect(run.reload.failure_reason).to eq("attachment_upload_in_progress")
      end
    end
  end

  describe ".update_external_release" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if not allowed" do
      run = create(:deployment_run, :submitted_for_review)

      expect(described_class.update_external_release(run)).to be_nil

      expect(run.reload.submitted_for_review?).to be(true)
    end

    context "when testflight" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :submitted_for_review, :with_external_release, step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }
      let(:base_build_info) {
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: "1.2.0",
          build_number: "123",
          added_at: "2023-02-25T03:02:46-08:00"
        }
      }
      let(:initial_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "WAITING_FOR_BETA_REVIEW")) }
      let(:in_progress_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "IN_BETA_REVIEW")) }
      let(:success_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "BETA_APPROVED")) }
      let(:rejected_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "BETA_REJECTED")) }
      let(:failure_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "MISSING_EXPORT_COMPLIANCE")) }

      it "finds build" do
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { initial_build_info })

        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(providable_dbl).to have_received(:find_build).with(run.build_number).once
      end

      it "creates external release" do
        run_without_external_release = create_deployment_run_tree(:ios, :submitted_for_review)[:deployment_run]
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { initial_build_info })

        expect(run_without_external_release.external_release).not_to be_present
        expect { described_class.update_external_release(run_without_external_release) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(run_without_external_release.reload.external_release).to be_present
        expect(run_without_external_release.reload.external_release.attributes.with_indifferent_access.slice(:added_at, :build_number, :external_id, :name, :status))
          .to eq(initial_build_info.attributes.with_indifferent_access)
      end

      it "updates external release if it exists" do
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { in_progress_build_info })

        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(run.reload.external_release.attributes.with_indifferent_access.slice(:added_at, :build_number, :external_id, :name, :status))
          .to eq(in_progress_build_info.attributes.with_indifferent_access)
      end

      it "marks deployment run as completed if build is successful" do
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { success_build_info })

        described_class.update_external_release(run)

        expect(run.reload.released?).to be(true)
      end

      it "adds reviewed at to external release if build is successful" do
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { success_build_info })

        freeze_time do
          described_class.update_external_release(run)

          expect(run.external_release.reload.reviewed_at).to eq(Time.current)
        end
      end

      it "marks the deployment run as review failed when rejected" do
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { rejected_build_info })

        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(run.reload.review_failed?).to be(true)
      end

      it "marks the deployment run as failed when failure" do
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { failure_build_info })

        described_class.update_external_release(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the failure reason as review failed when failure" do
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { failure_build_info })

        described_class.update_external_release(run)

        expect(run.reload.failure_reason).to eq("developer_rejected")
      end

      it "raises error to re-poll when find build fails" do
        error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}})
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { raise(error) })

        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(run.reload.failed?).to be(false)
      end
    end

    context "when production" do
      let(:factory_tree) { create_deployment_run_tree(:ios, :submitted_for_review, deployment_traits: [:with_production_channel], step_traits: [:release]) }
      let(:run) { factory_tree[:deployment_run] }
      let(:base_release_info) {
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: "1.2.0",
          build_number: "123",
          added_at: 1.day.ago,
          phased_release_status: "INACTIVE",
          phased_release_day: 0
        }
      }
      let(:initial_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "WAITING_FOR_REVIEW")) }
      let(:in_progress_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "IN_REVIEW")) }
      let(:success_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "PENDING_DEVELOPER_RELEASE")) }
      let(:rejected_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "REJECTED")) }
      let(:failure_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "DEVELOPER_REJECTED")) }

      it "finds release" do
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { initial_release_info })

        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(providable_dbl).to have_received(:find_release).with(run.build_number).once
      end

      it "creates external release" do
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { initial_release_info })

        expect(run.external_release).not_to be_present
        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(run.reload.external_release).to be_present
      end

      it "updates external release if it exists" do
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { in_progress_release_info })

        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(run.external_release.reload.status).to eq("IN_REVIEW")
      end

      it "marks deployment run as ready to release if review is successful" do
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { success_release_info })

        described_class.update_external_release(run)

        expect(run.reload.ready_to_release?).to be(true)
      end

      it "marks the deployment run as review failed when rejected" do
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { rejected_release_info })

        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(run.reload.review_failed?).to be(true)
      end

      it "marks the deployment run as submitted for review when a rejected release is resubmitted" do
        run.review_failed!
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { in_progress_release_info })

        described_class.update_external_release(run)

        expect(run.reload.submitted_for_review?).to be(true)
      end

      it "marks the deployment run as failed when failure" do
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { failure_release_info })

        described_class.update_external_release(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the failure reason as developer rejected when failure" do
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { failure_release_info })

        described_class.update_external_release(run)

        expect(run.reload.failure_reason).to eq("developer_rejected")
      end

      it "raises error to re-poll when find build fails" do
        error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}})
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { raise(error) })

        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(run.reload.failed?).to be(false)
      end
    end
  end

  describe ".start_release!" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }
    let(:factory_tree) { create_deployment_run_tree(:ios, :ready_to_release, deployment_traits: [:with_production_channel], step_traits: [:release]) }
    let(:run) { factory_tree[:deployment_run] }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if not allowed" do
      allow(providable_dbl).to receive(:start_release).and_return(GitHub::Result.new)
      disallowed_run = create(:deployment_run, :ready_to_release)

      expect(described_class.start_release!(disallowed_run)).to be_nil

      expect(providable_dbl).not_to have_received(:start_release)
    end

    context "when successful" do
      before do
        allow(providable_dbl).to receive(:start_release).and_return(GitHub::Result.new)
      end

      it "starts the release" do
        described_class.start_release!(run)

        expect(providable_dbl).to have_received(:start_release).with(run.build_number).once
      end

      it "creates staged rollout if staged rollout enabled" do
        run_with_staged_rollout = create_deployment_run_tree(:ios, :ready_to_release, deployment_traits: [:with_phased_release], step_traits: [:release])[:deployment_run]
        described_class.start_release!(run_with_staged_rollout)

        expect(run_with_staged_rollout.reload.staged_rollout).to be_present
      end

      it "starts release on the deployment run" do
        described_class.start_release!(run)

        expect(run.reload.rollout_started?).to be(true)
      end

      it "start the live release poll job" do
        poll_job = Deployments::AppStoreConnect::FindLiveReleaseJob
        allow(poll_job).to receive(:perform_async)

        described_class.start_release!(run)

        expect(poll_job).to have_received(:perform_async).with(run.id)
      end
    end

    context "when failure" do
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}}) }

      before do
        allow(providable_dbl).to receive(:start_release).and_return(GitHub::Result.new { raise error })
      end

      it "marks the deployment run as failed when failure" do
        described_class.start_release!(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        described_class.start_release!(run)

        expect(run.reload.failure_reason).to eq("build_not_found")
      end
    end
  end

  describe ".track_live_release_status" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }
    let(:build_number) { "123" }
    let(:factory_tree) { create_deployment_run_tree(:ios, :rollout_started, :with_external_release, deployment_traits: [:with_production_channel], step_traits: [:release]) }
    let(:run) { factory_tree[:deployment_run] }
    let(:base_release_info) {
      {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        name: "1.2.0",
        build_number: build_number,
        added_at: 1.day.ago
      }
    }
    let(:initial_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "PENDING_DEVELOPER_RELEASE")) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if not allowed" do
      allow(providable_dbl).to receive(:find_live_release)
      disallowed_run = create(:deployment_run, :rollout_started)

      expect(described_class.track_live_release_status(disallowed_run)).to be_nil

      expect(providable_dbl).not_to have_received(:find_live_release)
    end

    it "finds the live release" do
      allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { initial_release_info })

      expect { described_class.track_live_release_status(run) }
        .to raise_error(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)

      expect(providable_dbl).to have_received(:find_live_release).once
    end

    context "when staged rollout" do
      let(:live_phased_release_info) {
        AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "READY_FOR_SALE",
          phased_release_day: 1,
          phased_release_status: "ACTIVE"))
      }

      let(:last_phase_phased_release_info) {
        AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "READY_FOR_SALE",
          phased_release_day: 7,
          phased_release_status: "ACTIVE"))
      }

      let(:fully_live_phased_release_info) {
        AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "READY_FOR_SALE",
          phased_release_day: 8,
          phased_release_status: "COMPLETE"))
      }

      let(:run_with_staged_rollout) {
        create_deployment_run_tree(:ios, :rollout_started, :with_external_release, deployment_traits: [:with_phased_release], step_traits: [:release])[:deployment_run]
      }

      before do
        run_with_staged_rollout.step_run.update(build_number: build_number)
        run_with_staged_rollout.create_staged_rollout!(config: run_with_staged_rollout.staged_rollout_config)
      end

      it "updates staged rollout to 100% and raises release not fully live yet" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { last_phase_phased_release_info })

        expect { described_class.track_live_release_status(run_with_staged_rollout) }
          .to raise_error(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)

        expect(run_with_staged_rollout.staged_rollout.reload.started?).to be(true)
        expect(run_with_staged_rollout.staged_rollout.reload.last_rollout_percentage).to eq(100.0)
      end

      it "updates staged rollout and raises release not fully live yet" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { live_phased_release_info })

        expect { described_class.track_live_release_status(run_with_staged_rollout) }
          .to raise_error(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)

        expect(run_with_staged_rollout.staged_rollout.reload.started?).to be(true)
        expect(run_with_staged_rollout.staged_rollout.reload.last_rollout_percentage).to eq(1.0)
      end

      it "does not update staged rollout if stage hasn't changed" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { live_phased_release_info })
        run_with_staged_rollout.staged_rollout.update!(current_stage: 0, status: "started")
        old_updated_at = run_with_staged_rollout.staged_rollout.updated_at

        expect { described_class.track_live_release_status(run_with_staged_rollout) }
          .to raise_error(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)

        expect(run_with_staged_rollout.staged_rollout.reload.updated_at).to eq(old_updated_at)
        expect(run_with_staged_rollout.staged_rollout.reload.last_rollout_percentage).to eq(1.0)
      end

      it "marks finished but does not update staged rollout if stage hasn't changed but phased rollout is complete" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { fully_live_phased_release_info })
        run_with_staged_rollout.staged_rollout.update!(current_stage: 6, status: "started")

        described_class.track_live_release_status(run_with_staged_rollout)

        expect(run_with_staged_rollout.staged_rollout.reload.completed?).to be(true)
        expect(run_with_staged_rollout.staged_rollout.reload.last_rollout_percentage).to eq(100.0)
      end

      it "completes the run if staged rollout has finished" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { fully_live_phased_release_info })

        described_class.track_live_release_status(run_with_staged_rollout)

        expect(run_with_staged_rollout.staged_rollout.reload.completed?).to be(true)
        expect(run_with_staged_rollout.staged_rollout.reload.last_rollout_percentage).to eq(100.0)
        expect(run_with_staged_rollout.reload.released?).to be(true)
      end

      it "adds released at to the external release" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { fully_live_phased_release_info })

        freeze_time do
          described_class.track_live_release_status(run_with_staged_rollout)

          expect(run_with_staged_rollout.external_release.reload.released_at).to eq(Time.current)
        end
      end
    end

    context "when no staged rollout" do
      let(:live_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "READY_FOR_SALE")) }

      before do
        run.step_run.update(build_number: build_number)
        repo_integration = instance_double(Installations::Github::Api)
        allow(Installations::Github::Api).to receive(:new).and_return(repo_integration)
        allow(repo_integration).to receive(:create_tag!)
      end

      it "completes the run" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { live_release_info })

        described_class.track_live_release_status(run)

        expect(run.reload.released?).to be(true)
      end

      it "adds released at to the external release" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { live_release_info })

        freeze_time do
          described_class.track_live_release_status(run)

          expect(run.external_release.released_at).to eq(Time.current)
        end
      end
    end

    it "raises error to re-poll when failure" do
      error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}})
      allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { raise error })

      expect { described_class.track_live_release_status(run) }
        .to raise_error(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)

      expect(run.reload.failed?).to be(false)
    end
  end

  describe ".complete_phased_release!" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }
    let(:build_number) { "123" }
    let(:factory_tree) { create_deployment_run_tree(:ios, :rollout_started, :with_external_release, deployment_traits: [:with_phased_release], step_traits: [:release]) }
    let(:run) { factory_tree[:deployment_run] }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    context "when successful" do
      let(:live_release_info) {
        AppStoreIntegration::AppStoreReleaseInfo.new(
          {
            external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
            name: "1.2.0",
            build_number: build_number,
            added_at: 1.day.ago,
            status: "READY_FOR_SALE",
            phased_release_day: 1,
            phased_release_status: "COMPLETE"
          }
        )
      }

      before do
        run.step_run.update(build_number: build_number)
        run.create_staged_rollout(config: run.deployment.staged_rollout_config)
        allow(providable_dbl).to receive(:complete_phased_release).and_return(GitHub::Result.new { live_release_info })
      end

      it "completes the phased release" do
        described_class.complete_phased_release!(run)

        expect(providable_dbl).to have_received(:complete_phased_release).once
      end

      it "updates the external release" do
        described_class.complete_phased_release!(run)

        expect(run.external_release.reload.status).to eq("READY_FOR_SALE")
      end
    end

    context "when failed" do
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "release", "code" => "phased_release_not_found"}}) }

      before do
        allow(providable_dbl).to receive(:complete_phased_release).and_return(GitHub::Result.new { raise error })
      end

      it "fails the deployment run" do
        described_class.complete_phased_release!(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the failure reason to the deployment run" do
        described_class.complete_phased_release!(run)

        expect(run.reload.failure_reason).to eq("phased_release_not_found")
      end
    end
  end
end
