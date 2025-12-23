require "rails_helper"

RSpec.describe WebHandlers::UpdateReleasePlatformConfig do
  subject(:service) do
    described_class.new(config, params, submission_types, ci_actions, release_platform)
  end

  let(:release_platform) { create(:release_platform) }
  let(:config) { release_platform.platform_config }
  let(:app) { release_platform.app }

  let(:submission_types) do
    {
      variants: [
        {
          id: app.id,
          type: "App",
          submissions: [
            {
              type: "PlayStoreSubmission",
              channels: [
                {id: "internal_channel", name: "Internal Track", is_internal: true},
                {id: "alpha_channel", name: "Alpha Track", is_internal: false}
              ]
            }
          ]
        }
      ]
    }
  end

  let(:ci_actions) do
    [
      {id: "workflow_1", name: "Build and Deploy"},
      {id: "workflow_2", name: "Release Build"}
    ]
  end

  describe "#call" do
    describe "conditional destruction" do
      context "when disabling internal releases" do
        before do
          # First enable internal release
          config.update!(
            internal_workflow: Config::Workflow.new(kind: "internal", name: "Internal", identifier: "workflow_1"),
            internal_release: Config::ReleaseStep.new(kind: "internal")
          )
        end

        let(:params) do
          {
            internal_release_enabled: "false",
            internal_release_attributes: {id: config.internal_release.id},
            internal_workflow_attributes: {id: config.internal_workflow.id}
          }
        end

        it "marks internal release and workflow for destruction" do
          expect(service.call).to be true

          config.reload
          expect(config.internal_release).to be_nil
          expect(config.internal_workflow).to be_nil
        end
      end

      context "when disabling beta release submissions" do
        before do
          beta_release = config.beta_release
          beta_release.submissions.create!(
            submission_type: "PlayStoreSubmission",
            integrable: app,
            submission_external: Config::SubmissionExternal.new(identifier: "internal_channel", name: "Internal")
          )
        end

        let(:params) do
          {
            beta_release_submissions_enabled: "false",
            beta_release_attributes: {
              id: config.beta_release.id,
              submissions_attributes: {
                "0" => {
                  id: config.beta_release.submissions.first.id,
                  submission_external_attributes: {
                    id: config.beta_release.submissions.first.submission_external.id
                  }
                }
              }
            }
          }
        end

        it "marks beta submissions and externals for destruction" do
          expect(service.call).to be true

          config.reload
          expect(config.beta_release.submissions).to be_empty
        end
      end

      context "when disabling production release" do
        before do
          # Add internal release so we have at least one valid release step after disabling production
          config.update!(
            internal_workflow: Config::Workflow.new(kind: "internal", name: "Internal", identifier: "workflow_1"),
            internal_release: Config::ReleaseStep.new(kind: "internal")
          )
        end

        let(:params) do
          {
            internal_release_enabled: "true",
            production_release_enabled: "false",
            production_release_attributes: {id: config.production_release.id}
          }
        end

        it "marks production release for destruction" do
          expect { service.call }.to change { config.reload.production_release }.to(nil)
        end
      end
    end

    describe "workflow data transformation" do
      context "when workflow has identifier" do
        let(:params) do
          {
            release_candidate_workflow_attributes: {
              id: config.release_candidate_workflow.id,
              identifier: "workflow_1"
            }
          }
        end

        it "adds workflow name from ci_actions" do
          expect(service.call).to be true

          config.reload
          expect(config.release_candidate_workflow.name).to eq("Build and Deploy")
        end
      end

      context "when internal workflow has identifier" do
        before do
          config.update!(
            internal_workflow: Config::Workflow.new(kind: "internal", name: "Old Name", identifier: "old_id"),
            internal_release: Config::ReleaseStep.new(kind: "internal")
          )
        end

        let(:params) do
          {
            internal_release_enabled: "true",
            internal_workflow_attributes: {
              id: config.internal_workflow.id,
              identifier: "workflow_2"
            }
          }
        end

        it "updates internal workflow name" do
          expect(service.call).to be true

          config.reload
          expect(config.internal_workflow.name).to eq("Release Build")
        end
      end

      context "when workflow identifier is blank" do
        let(:params) do
          {
            production_release_enabled: "true",
            release_candidate_workflow_attributes: {
              id: config.release_candidate_workflow.id,
              identifier: ""
            }
          }
        end

        it "fails validation because identifier is required" do
          expect(service.call).to be false
          expect(service.errors).not_to be_empty
        end
      end

      context "when workflow identifier not found in ci_actions" do
        let(:params) do
          {
            production_release_enabled: "true",
            release_candidate_workflow_attributes: {
              id: config.release_candidate_workflow.id,
              identifier: "nonexistent_workflow"
            }
          }
        end

        it "fails validation because name cannot be nil" do
          expect(service.call).to be false
          expect(service.errors).not_to be_empty
        end
      end
    end

    describe "submission data transformation" do
      context "when adding a new submission" do
        let(:params) do
          {
            beta_release_submissions_enabled: "true",
            beta_release_attributes: {
              id: config.beta_release.id,
              submissions_attributes: {
                "0" => {
                  integrable_id: app.id,
                  submission_type: "PlayStoreSubmission",
                  submission_external_attributes: {
                    identifier: "internal_channel"
                  }
                }
              }
            }
          }
        end

        it "sets integrable_type from variant lookup" do
          expect(service.call).to be true

          config.reload
          submission = config.beta_release.submissions.first
          expect(submission.integrable_type).to eq("App")
        end

        it "sets submission_external name and internal flag from channel lookup" do
          expect(service.call).to be true

          config.reload
          external = config.beta_release.submissions.first.submission_external
          expect(external.name).to eq("Internal Track")
          expect(external.internal).to be true
        end
      end

      context "when variant is not found" do
        let(:params) do
          {
            beta_release_submissions_enabled: "true",
            beta_release_attributes: {
              id: config.beta_release.id,
              submissions_attributes: {
                "0" => {
                  integrable_id: "nonexistent_variant",
                  submission_type: "PlayStoreSubmission"
                }
              }
            }
          }
        end

        it "does not set integrable_type" do
          service.call

          config.reload
          submission = config.beta_release.submissions.first
          expect(submission&.integrable_type).to be_nil
        end
      end

      context "when submission_external_attributes is missing" do
        let(:params) do
          {
            beta_release_submissions_enabled: "true",
            beta_release_attributes: {
              id: config.beta_release.id,
              submissions_attributes: {
                "0" => {
                  integrable_id: app.id,
                  submission_type: "PlayStoreSubmission"
                }
              }
            }
          }
        end

        it "still sets integrable_type" do
          service.call

          config.reload
          submission = config.beta_release.submissions.first
          expect(submission&.integrable_type).to eq("App")
        end
      end
    end

    describe "production data transformation (Android)" do
      context "when rollout is enabled" do
        let(:params) do
          {
            production_release_enabled: "true",
            production_release_attributes: {
              id: config.production_release.id,
              submissions_attributes: {
                "0" => {
                  id: config.production_release.submissions.first.id,
                  rollout_enabled: "true",
                  rollout_stages: "1,5,10,50,100"
                }
              }
            }
          }
        end

        it "parses rollout_stages as array of floats" do
          expect(service.call).to be true

          config.reload
          submission = config.production_release.submissions.first
          expect(submission.rollout_stages).to eq([1.0, 5.0, 10.0, 50.0, 100.0])
        end
      end

      context "when rollout is enabled with finish_rollout_in_next_release" do
        let(:params) do
          {
            production_release_enabled: "true",
            production_release_attributes: {
              id: config.production_release.id,
              submissions_attributes: {
                "0" => {
                  id: config.production_release.submissions.first.id,
                  rollout_enabled: "true",
                  rollout_stages: "1,5,10,50",
                  finish_rollout_in_next_release: "true"
                }
              }
            }
          }
        end

        it "preserves finish_rollout_in_next_release when last stage is less than 100" do
          expect(service.call).to be true

          config.reload
          submission = config.production_release.submissions.first
          expect(submission.finish_rollout_in_next_release).to be true
        end
      end

      context "when rollout is disabled" do
        let(:params) do
          {
            production_release_enabled: "true",
            production_release_attributes: {
              id: config.production_release.id,
              submissions_attributes: {
                "0" => {
                  id: config.production_release.submissions.first.id,
                  rollout_enabled: "false",
                  rollout_stages: "1,5,10",
                  finish_rollout_in_next_release: "true"
                }
              }
            }
          }
        end

        it "clears rollout_stages" do
          expect(service.call).to be true

          config.reload
          submission = config.production_release.submissions.first
          expect(submission.rollout_stages).to eq([])
        end

        it "sets finish_rollout_in_next_release to false" do
          expect(service.call).to be true

          config.reload
          submission = config.production_release.submissions.first
          expect(submission.finish_rollout_in_next_release).to be false
        end
      end
    end

    describe "production data transformation (iOS)" do
      let(:release_platform) { create(:release_platform, platform: "ios") }

      let(:params) do
        {
          production_release_enabled: "true",
          production_release_attributes: {
            id: config.production_release.id,
            submissions_attributes: {
              "0" => {
                id: config.production_release.submissions.first.id
              }
            }
          }
        }
      end

      it "skips rollout transformation for iOS" do
        original_stages = config.production_release.submissions.first.rollout_stages

        expect(service.call).to be true

        config.reload
        submission = config.production_release.submissions.first
        expect(submission.rollout_stages).to eq(original_stages)
      end
    end

    describe "error handling" do
      context "when validation fails due to missing release steps" do
        before do
          # Add internal release so we can try to disable all release steps
          config.update!(
            internal_workflow: Config::Workflow.new(kind: "internal", name: "Internal", identifier: "workflow_1"),
            internal_release: Config::ReleaseStep.new(kind: "internal")
          )
        end

        let(:params) do
          {
            # Disable all release steps - this should fail validation
            production_release_enabled: "false",
            production_release_attributes: {id: config.production_release.id, _destroy: "1"},
            internal_release_enabled: "false",
            internal_release_attributes: {id: config.internal_release.id, _destroy: "1"},
            internal_workflow_attributes: {id: config.internal_workflow.id, _destroy: "1"}
          }
        end

        it "returns false" do
          expect(service.call).to be false
        end

        it "populates errors" do
          service.call
          expect(service.errors).not_to be_empty
        end

        it "rolls back transaction" do
          original_production = config.production_release

          service.call

          config.reload
          expect(config.production_release).to eq(original_production)
        end
      end

      context "when beta submissions enabled but no submissions provided" do
        let(:params) do
          {
            production_release_enabled: "true",
            beta_release_submissions_enabled: "true",
            beta_release_attributes: {
              id: config.beta_release.id,
              submissions_attributes: {}
            }
          }
        end

        it "returns false due to incomplete beta releases" do
          expect(service.call).to be false
        end

        it "populates errors" do
          service.call
          expect(service.errors).not_to be_empty
        end
      end
    end

    describe "submission reordering with positioning gem" do
      let!(:first_submission) do
        config.beta_release.submissions.create!(
          submission_type: "PlayStoreSubmission",
          integrable: app,
          submission_external: Config::SubmissionExternal.new(identifier: "channel_first", name: "Channel First")
        )
      end

      let!(:second_submission) do
        config.beta_release.submissions.create!(
          submission_type: "PlayStoreSubmission",
          integrable: app,
          submission_external: Config::SubmissionExternal.new(identifier: "channel_second", name: "Channel Second")
        )
      end

      let(:params) do
        {
          production_release_enabled: "true",
          beta_release_submissions_enabled: "true",
          beta_release_attributes: {
            id: config.beta_release.id,
            submissions_attributes: {
              "0" => {
                id: second_submission.id,
                number: "1"
              },
              "1" => {
                id: first_submission.id,
                number: "2"
              }
            }
          }
        }
      end

      it "reorders submissions based on number param" do
        expect(service.call).to be true

        config.reload
        ordered_ids = config.beta_release.submissions.order(:number).pluck(:id)
        expect(ordered_ids).to eq([second_submission.id, first_submission.id])
      end
    end
  end
end
