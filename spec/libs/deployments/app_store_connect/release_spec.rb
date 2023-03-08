# frozen_string_literal: true

require "rails_helper"

describe Deployments::AppStoreConnect::Release do
  describe ".kickoff!" do
    let(:test_flight_job) { Deployments::AppStoreConnect::TestFlightReleaseJob }
    let(:app_store_job) { Deployments::AppStoreConnect::PrepareForReleaseJob }

    before do
      allow(test_flight_job).to receive(:perform_later)
      allow(app_store_job).to receive(:perform_later)
    end

    it "does nothing if not allowed" do
      run = create(:deployment_run)
      expect(described_class.kickoff!(run)).to be_nil

      expect(app_store_job).not_to have_received(:perform_later)
      expect(test_flight_job).not_to have_received(:perform_later)
    end

    context "when production channel" do
      let(:run) {
        create_deployment_run_for_ios(
          :started,
          deployment_traits: [:with_app_store, :with_production_channel],
          step_trait: :release
        )
      }

      it "starts preparing the release" do
        described_class.kickoff!(run)

        expect(app_store_job).to have_received(:perform_later).with(run.id).once
      end
    end

    context "when not production channel" do
      let(:run) {
        create_deployment_run_for_ios(
          :started,
          deployment_traits: [:with_app_store],
          step_trait: :review
        )
      }

      it "starts adding to beta group when testflight" do
        described_class.kickoff!(run)

        expect(test_flight_job).to have_received(:perform_later).with(run.id).once
      end
    end
  end

  describe ".to_test_flight!" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if not allowed" do
      run = create_deployment_run_for_ios(
        :started,
        deployment_traits: [:with_app_store, :with_production_channel],
        step_trait: :release
      )

      expect(described_class.to_test_flight!(run)).to be_nil

      expect(run.reload.started?).to be(true)
    end

    context "when successful" do
      let(:run) {
        create_deployment_run_for_ios(
          :started,
          deployment_traits: [:with_app_store],
          step_trait: :release
        )
      }

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
      let(:run) {
        create_deployment_run_for_ios(
          :started,
          deployment_traits: [:with_app_store],
          step_trait: :release
        )
      }
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
      run = create(:deployment_run, :started)

      expect(described_class.prepare_for_release!(run)).to be_nil

      expect(run.reload.started?).to be(true)
    end

    context "when successful" do
      let(:run) {
        create_deployment_run_for_ios(
          :started,
          deployment_traits: [:with_app_store, :with_production_channel],
          step_trait: :release
        )
      }

      before do
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new)
      end

      it "prepares the release" do
        described_class.prepare_for_release!(run)

        expect(providable_dbl).to have_received(:prepare_release).with(run.build_number, run.release_version, false).once
      end

      it "marks the deployment run as prepared release" do
        described_class.prepare_for_release!(run)

        expect(run.reload.prepared_release?).to be(true)
      end

      it "prepares the release for staged deployment" do
        run = create_deployment_run_for_ios(:started, deployment_traits: [:with_phased_release, :with_app_store], step_trait: :release)
        described_class.prepare_for_release!(run)

        expect(providable_dbl).to have_received(:prepare_release).with(run.build_number, run.release_version, true).once
      end
    end

    context "when failure" do
      let(:run) {
        create_deployment_run_for_ios(
          :started,
          deployment_traits: [:with_app_store, :with_production_channel],
          step_trait: :release
        )
      }
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
      let(:run) {
        create_deployment_run_for_ios(
          :prepared_release,
          deployment_traits: [:with_app_store, :with_production_channel],
          step_trait: :release
        )
      }

      before do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new)
      end

      it "submits the release" do
        described_class.submit_for_review!(run)

        expect(providable_dbl).to have_received(:submit_release).with(run.build_number).once
      end

      it "marks the deployment run as submitted" do
        described_class.submit_for_review!(run)

        expect(run.reload.submitted_for_review?).to be(true)
      end
    end

    context "when failure" do
      let(:run) { create_deployment_run_for_ios(:started, deployment_traits: [:with_app_store, :with_production_channel], step_trait: :release) }
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}}) }

      before do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new { raise error })
      end

      it "marks the deployment run as failed when failure" do
        described_class.submit_for_review!(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        described_class.submit_for_review!(run)

        expect(run.reload.failure_reason).to eq("build_not_found")
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
      let(:run) { create_deployment_run_for_ios(:submitted_for_review, deployment_traits: [:with_app_store]) }
      let(:base_build_info) {
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: "1.2.0",
          build_number: "123",
          added_at: 1.day.ago
        }
      }
      let(:initial_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "WAITING_FOR_BETA_REVIEW")) }
      let(:in_progress_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "IN_BETA_REVIEW")) }
      let(:success_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "BETA_APPROVED")) }
      let(:failure_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "BETA_REJECTED")) }

      it "finds build" do
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { initial_build_info })

        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(providable_dbl).to have_received(:find_build).with(run.build_number).once
      end

      it "creates external release" do
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { initial_build_info })

        expect(run.external_release).not_to be_present
        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(run.reload.external_release).to be_present
        expect(run.reload.external_release.attributes.with_indifferent_access.slice(:added_at, :build_number, :external_id, :name, :status))
          .to eq(initial_build_info.attributes.with_indifferent_access)
      end

      it "updates external release if it exists" do
        run.create_external_release(initial_build_info.attributes)
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

      it "marks the deployment run as failed when failure" do
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { failure_build_info })

        described_class.update_external_release(run)

        expect(run.reload.failed?).to be(true)
      end

      it "marks the deployment run as failed when find build fails" do
        error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}})
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { raise(error) })

        described_class.update_external_release(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}})
        allow(providable_dbl).to receive(:find_build).and_return(GitHub::Result.new { raise(error) })

        described_class.update_external_release(run)

        expect(run.reload.failure_reason).to eq("build_not_found")
      end
    end

    context "when production" do
      let(:run) {
        create_deployment_run_for_ios(
          :submitted_for_review,
          deployment_traits: [:with_app_store, :with_production_channel],
          step_trait: :release
        )
      }
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
      let(:failure_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "REJECTED")) }

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
        run.create_external_release(initial_release_info.attributes)
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { in_progress_release_info })

        expect { described_class.update_external_release(run) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(run.external_release.reload.status).to eq("IN_REVIEW")
      end

      it "marks deployment run as completed if build is successful" do
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { success_release_info })

        described_class.update_external_release(run)

        expect(run.reload.ready_to_release?).to be(true)
      end

      it "marks the deployment run as failed when failure" do
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { failure_release_info })

        described_class.update_external_release(run)

        expect(run.reload.failed?).to be(true)
      end

      it "marks the deployment run as failed when find build fails" do
        error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}})
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { raise(error) })

        described_class.update_external_release(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}})
        allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { raise(error) })

        described_class.update_external_release(run)

        expect(run.reload.failure_reason).to eq("build_not_found")
      end
    end
  end

  describe ".start_release!" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }
    let(:run) {
      create_deployment_run_for_ios(
        :ready_to_release,
        deployment_traits: [:with_app_store, :with_production_channel],
        step_trait: :release
      )
    }

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
        run_with_staged_rollout = create_deployment_run_for_ios(:ready_to_release,
          deployment_traits: [:with_app_store, :with_phased_release],
          step_trait: :release)
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
    let(:run) {
      create_deployment_run_for_ios(
        :rollout_started,
        deployment_traits: [:with_app_store, :with_production_channel],
        step_trait: :release
      )
    }
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
      run.create_external_release
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

      let(:fully_live_phased_release_info) {
        AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "READY_FOR_SALE",
          phased_release_day: 8,
          phased_release_status: "COMPLETE"))
      }

      let(:run_with_staged_rollout) {
        create_deployment_run_for_ios(
          :rollout_started,
          deployment_traits: [:with_app_store, :with_phased_release],
          step_trait: :release
        )
      }

      before do
        run_with_staged_rollout.step_run.update(build_number: build_number)
        run_with_staged_rollout.create_external_release(initial_release_info.attributes)
        run_with_staged_rollout.create_staged_rollout!(config: run_with_staged_rollout.staged_rollout_config)
      end

      it "updates staged rollout and raises release not fully live yet" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { live_phased_release_info })

        expect { described_class.track_live_release_status(run_with_staged_rollout) }
          .to raise_error(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)

        expect(run_with_staged_rollout.staged_rollout.reload.started?).to be(true)
        expect(run_with_staged_rollout.staged_rollout.reload.last_rollout_percentage).to eq(1.0)
      end

      it "completes the run if staged rollout has finished" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { fully_live_phased_release_info })

        described_class.track_live_release_status(run_with_staged_rollout)

        expect(run_with_staged_rollout.staged_rollout.reload.finished?).to be(true)
        expect(run_with_staged_rollout.staged_rollout.reload.last_rollout_percentage).to eq(100.0)
        expect(run_with_staged_rollout.reload.released?).to be(true)
      end

      it "adds released at to the external release" do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { fully_live_phased_release_info })

        freeze_time do
          described_class.track_live_release_status(run_with_staged_rollout)

          expect(run_with_staged_rollout.external_release.released_at).to eq(Time.current)
        end
      end
    end

    context "when no staged rollout" do
      let(:live_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "READY_FOR_SALE")) }

      before do
        run.step_run.update(build_number: build_number)
        run.create_external_release(initial_release_info.attributes)
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

    context "when failure" do
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}}) }

      before do
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { raise error })
      end

      it "marks the deployment run as failed when failure" do
        described_class.track_live_release_status(run)

        expect(run.reload.failed?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        described_class.track_live_release_status(run)

        expect(run.reload.failure_reason).to eq("build_not_found")
      end
    end
  end

  describe ".complete_phased_release!" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }
    let(:build_number) { "123" }
    let(:run) {
      create_deployment_run_for_ios(
        :rollout_started,
        deployment_traits: [:with_app_store, :with_phased_release],
        step_trait: :release
      )
    }

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
        run.create_external_release
        run.create_staged_rollout(config: run.deployment.staged_rollout_config)
        allow(providable_dbl).to receive(:complete_phased_release).and_return(GitHub::Result.new)
        allow(providable_dbl).to receive(:find_live_release).and_return(GitHub::Result.new { live_release_info })
      end

      it "completes the phased release" do
        described_class.complete_phased_release!(run)

        expect(providable_dbl).to have_received(:complete_phased_release).once
      end

      it "releases the deployment run" do
        described_class.complete_phased_release!(run)

        expect(run.reload.released?).to be(true)
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
