require "rails_helper"

describe Deployments::GooglePlayStore::Release do
  describe ".kickoff!" do
    let(:step) { create(:step, :with_deployment) }
    let(:step_run) { create(:step_run, :deployment_started, step: step) }

    it "marks as uploaded if there is another similar deployment which has uploaded" do
      integration = create(:integration, :with_google_play_store)
      deployment1 = create(:deployment, step: step, integration: integration)
      deployment2 = create(:deployment, step: step, integration: integration)
      _uploaded_run = create(:deployment_run, :uploaded, deployment: deployment1, step_run: step_run)
      deployment_run = create(:deployment_run, :started, deployment: deployment2, step_run: step_run)

      described_class.kickoff!(deployment_run)
      expect(deployment_run.reload.uploaded?).to be(true)
    end

    it "starts upload if there is another similar deployment but not store" do
      skip "not implemented yet"
      integration = create(:integration, :with_slack)
      deployment1 = create(:deployment, step: step, integration: integration)
      deployment2 = create(:deployment, step: step, integration: integration)
      _uploaded_run = create(:deployment_run, :uploaded, deployment: deployment1, step_run: step_run)
      deployment_run = create(:deployment_run, :started, deployment: deployment2, step_run: step_run)
      allow(Deployments::SlackJob).to receive(:perform_later)

      described_class.kickoff!(deployment_run)
      expect(Deployments::SlackJob).to have_received(:perform_later).with(deployment_run.id).once
      expect(deployment_run.reload.started?).to be(true)
    end

    it "starts upload if it is the only deployment with google play store" do
      deployment = create(:deployment, :with_google_play_store, step: step)
      deployment_run = create(:deployment_run, :started, deployment: deployment, step_run: step_run)
      allow(Deployments::GooglePlayStore::Upload).to receive(:perform_later)

      described_class.kickoff!(deployment_run)

      expect(Deployments::GooglePlayStore::Upload).to have_received(:perform_later).with(deployment_run.id).once
      expect(deployment_run.reload.started?).to be(true)
    end

    it "starts upload if it is the only deployment with slack" do
      skip "not implemented yet"
      deployment = create(:deployment, :with_slack, step: step)
      deployment_run = create(:deployment_run, :started, deployment: deployment, step_run: step_run)
      allow(Deployments::SlackJob).to receive(:perform_later)

      described_class.kickoff!(deployment_run)
      expect(Deployments::SlackJob).to have_received(:perform_later).with(deployment_run.id).once
      expect(deployment_run.reload.started?).to be(true)
    end

    it "starts upload if a different deployment has happened before" do
      deployment1 = create(:deployment, step: step)
      _ignored_run = create(:deployment_run, :released, deployment: deployment1, step_run: step_run)

      deployment2 = create(:deployment, :with_google_play_store, step: step)
      deployment_run = create(:deployment_run, :started, deployment: deployment2, step_run: step_run)

      allow(Deployments::GooglePlayStore::Upload).to receive(:perform_later)

      described_class.kickoff!(deployment_run)
      expect(Deployments::GooglePlayStore::Upload).to have_received(:perform_later).with(deployment_run.id).once
      expect(deployment_run.reload.started?).to be(true)
    end
  end

  describe ".upload!" do
    let(:slack_deployment_run) { create(:deployment_run, :started, :with_slack) }
    let(:store_deployment_run) { create(:deployment_run, :started, :with_google_play_store) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if deployment is not google play store" do
      described_class.upload!(slack_deployment_run)
      expect(slack_deployment_run.reload.started?).to be true
    end

    it "uploads the package to store and marks the run as uploaded" do
      allow(providable_dbl).to receive(:upload).and_return(GitHub::Result.new)
      expect { described_class.upload!(store_deployment_run) }
        .to change(store_deployment_run, :uploaded?).from(false).to(true)
    end

    it "marks deployment runs as failed if upload fails" do
      allow(providable_dbl).to receive(:upload).and_return(GitHub::Result.new { raise })

      expect { described_class.upload!(store_deployment_run) }
        .to change(store_deployment_run, :failed?).from(false).to(true)
    end

    it "adds failure reason to deployment run if upload fails" do
      error_body = {"error" => {"status" => "PERMISSION_DENIED", "code" => 403, "message" => "We have failed to run 'bundletool build-apks' on this Android App Bundle. Please ensure your bundle is valid by running 'bundletool build-apks' locally and try again. Error message output: File 'BundleConfig.pb' was not found"}}
      error = ::Google::Apis::ClientError.new("Error", body: error_body.to_json)
      allow(providable_dbl).to receive(:upload).and_return(GitHub::Result.new { raise Installations::Google::PlayDeveloper::Error.new(error) })

      expect { described_class.upload!(store_deployment_run) }
        .to change(store_deployment_run, :failure_reason).from(nil).to("apks_not_allowed")
    end

    it "does not mark the run as uploaded twice or raise an exception" do
      allow(providable_dbl).to receive(:upload).and_return(GitHub::Result.new)
      described_class.upload!(store_deployment_run)
      expect { described_class.upload!(store_deployment_run) }.not_to change(store_deployment_run, :uploaded?)
    end
  end

  describe ".halt_release!" do
    let(:step) { create(:step, :release, :with_deployment) }
    let(:step_run) { create(:step_run, :deployment_started, step: step) }
    let(:deployment) { create(:deployment, :with_google_play_store, :with_staged_rollout, step: step_run.step) }
    let(:run) { create(:deployment_run, :rollout_started, :with_staged_rollout, deployment:, step_run:) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if rollout hasn't started" do
      unstarted_run = create(:deployment_run, :uploaded, deployment:, step_run:)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)

      described_class.halt_release!(unstarted_run)

      expect(providable_dbl).not_to have_received(:halt_release)
    end

    it "halts the deployments on playstore" do
      run.create_staged_rollout!(config: run.staged_rollout_config)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)

      described_class.halt_release!(run)

      expect(providable_dbl).to have_received(:halt_release)
    end
  end

  describe ".start_release!" do
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    context "when staged rollout" do
      let(:deployment_run) { create(:deployment_run, :uploaded, :with_google_play_store, :with_staged_rollout) }

      it "creates draft release" do
        allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
        described_class.start_release!(deployment_run)
        expect(providable_dbl).to have_received(:create_draft_release)
          .with(deployment_run.deployment_channel,
            deployment_run.build_number,
            deployment_run.release_version,
            [{language: "en-US",
              text: "The latest version contains bug fixes and performance improvements."}])
      end

      it "marks the run as release started" do
        allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
        expect { described_class.start_release!(deployment_run) }.to change(deployment_run, :rollout_started?)
      end

      it "marks the run as failed with manual action required when release fails due to app review rejection" do
        error_body = {"error" => {"status" => "INVALID_ARGUMENT",
                                  "code" => 400,
                                  "message" => "Changes cannot be sent for review automatically. Please set the query parameter changesNotSentForReview to true. Once committed, the changes in this edit can be sent for review from the Google Play Console UI"}}
        error = Google::Apis::ClientError.new("Error", body: error_body.to_json)
        allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new { raise Installations::Google::PlayDeveloper::Error.new(error) })
        expect { described_class.start_release!(deployment_run) }.to change(deployment_run, :failed_with_action_required?)
      end
    end

    context "when no staged rollout" do
      let(:deployment_run) { create(:deployment_run, :uploaded, :with_google_play_store) }

      it "creates release with full rollout for non-production channel" do
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
        described_class.start_release!(deployment_run)
        expect(providable_dbl).to have_received(:rollout_release)
          .with(deployment_run.deployment_channel,
            deployment_run.build_number,
            deployment_run.release_version,
            Deployment::FULL_ROLLOUT_VALUE,
            [{language: "en-US", text: "Nothing new"}])
      end

      it "creates release with full rollout for production channel" do
        deployment = create(:deployment, :with_release_step, :with_google_play_store, :with_production_channel)
        deployment_run = create(:deployment_run, deployment:)
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
        described_class.start_release!(deployment_run)
        expect(providable_dbl).to have_received(:rollout_release)
          .with(deployment_run.deployment_channel,
            deployment_run.build_number,
            deployment_run.release_version,
            Deployment::FULL_ROLLOUT_VALUE,
            [{language: "en-US",
              text: "The latest version contains bug fixes and performance improvements."}])
      end

      it "marks the run as released" do
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
        expect { described_class.start_release!(deployment_run) }.to change(deployment_run, :released?)
      end

      it "marks the run as failed with manual action required when release fails due to app review rejection" do
        error_body = {"error" => {"status" => "INVALID_ARGUMENT",
                                  "code" => 400,
                                  "message" => "Changes cannot be sent for review automatically. Please set the query parameter changesNotSentForReview to true. Once committed, the changes in this edit can be sent for review from the Google Play Console UI"}}
        error = Google::Apis::ClientError.new("Error", body: error_body.to_json)
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise Installations::Google::PlayDeveloper::Error.new(error) })
        expect { described_class.start_release!(deployment_run) }.to change(deployment_run, :failed_with_action_required?)
      end
    end

    context "when step run is restarted and release is not present in the channel" do
      context "when staged rollout" do
        let(:step) { create(:step, :with_deployment, :release) }
        let(:step_run) { create(:step_run, :deployment_restarted, step:) }
        let(:deployment_run) { create(:deployment_run, :uploaded, :with_google_play_store, :with_staged_rollout, step_run:) }

        it "creates the draft release" do
          allow(providable_dbl).to receive(:build_present_in_channel?).and_return(false)
          allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
          described_class.start_release!(deployment_run)
          expect(providable_dbl).to have_received(:create_draft_release)
            .with(deployment_run.deployment_channel,
              deployment_run.build_number,
              deployment_run.release_version,
              [{language: "en-US",
                text: "The latest version contains bug fixes and performance improvements."}])
        end

        it "marks a run as release started" do
          allow(providable_dbl).to receive(:build_present_in_channel?).and_return(false)
          allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
          expect { described_class.start_release!(deployment_run) }.to change(deployment_run, :rollout_started?)
        end
      end

      context "when no staged rollout" do
        let(:step_run) { create(:step_run, :deployment_restarted) }
        let(:deployment_run) { create(:deployment_run, :uploaded, :with_google_play_store, step_run:) }

        it "creates a full rollout release" do
          allow(providable_dbl).to receive(:build_present_in_channel?).and_return(false)
          allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
          described_class.start_release!(deployment_run)
          expect(providable_dbl).to have_received(:rollout_release)
            .with(deployment_run.deployment_channel,
              deployment_run.build_number,
              deployment_run.release_version,
              Deployment::FULL_ROLLOUT_VALUE,
              [{language: "en-US", text: "Nothing new"}])
        end

        it "marks a run as released when no staged rollout" do
          allow(providable_dbl).to receive(:build_present_in_channel?).and_return(false)
          allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
          expect { described_class.start_release!(deployment_run) }.to change(deployment_run, :released?)
        end
      end
    end

    context "when step run is restarted and release is present in the channel" do
      context "when staged rollout" do
        let(:step) { create(:step, :with_deployment, :release) }
        let(:step_run) { create(:step_run, :deployment_restarted, step:) }
        let(:deployment_run) { create(:deployment_run, :uploaded, :with_google_play_store, :with_staged_rollout, step_run:) }

        it "does not create the draft release" do
          allow(providable_dbl).to receive(:build_present_in_channel?).and_return(true)
          allow(providable_dbl).to receive(:create_draft_release)
          described_class.start_release!(deployment_run)
          expect(providable_dbl).not_to have_received(:create_draft_release)
        end

        it "marks a run as release started" do
          allow(providable_dbl).to receive(:build_present_in_channel?).and_return(true)
          allow(providable_dbl).to receive(:create_draft_release)
          expect { described_class.start_release!(deployment_run) }.to change(deployment_run, :rollout_started?)
        end
      end

      context "when no staged rollout" do
        let(:step_run) { create(:step_run, :deployment_restarted) }
        let(:deployment_run) { create(:deployment_run, :uploaded, :with_google_play_store, step_run:) }

        it "does not create a full rollout release" do
          allow(providable_dbl).to receive(:build_present_in_channel?).and_return(true)
          allow(providable_dbl).to receive(:rollout_release)
          described_class.start_release!(deployment_run)
          expect(providable_dbl).not_to have_received(:rollout_release)
        end

        it "marks a run as released when no staged rollout" do
          allow(providable_dbl).to receive(:build_present_in_channel?).and_return(true)
          allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
          expect { described_class.start_release!(deployment_run) }.to change(deployment_run, :released?)
        end
      end
    end
  end
end
