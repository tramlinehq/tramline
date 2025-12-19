require "rails_helper"

RSpec.describe WebHandlers::UpdateReleasePlatformConfig do
  subject(:service) do
    described_class.new(
      config,
      params,
      submission_types,
      ci_actions,
      release_platform
    )
  end

  let(:config) { create(:release_platform_config) }
  let(:submission_types) do
    {
      variants: [
        {
          id: "variant_1",
          type: "SubmissionType::Android",
          submissions: [
            {
              type: "internal",
              channels: [
                {id: "internal_channel", name: "Internal", is_internal: true}
              ]
            }
          ]
        }
      ]
    }
  end
  let(:ci_actions) do
    [
      {id: "workflow_1", name: "Build and Deploy"}
    ]
  end
  let(:release_platform) { create(:release_platform, :android) }

  describe "#call" do
    context "when updating internal release settings" do
      let(:params) do
        {
          internal_release_enabled: "true",
          internal_release_attributes: {
            submissions_attributes: {
              "0" => {
                integrable_id: "variant_1",
                submission_type: "internal",
                number: "1",
                submission_external_attributes: {
                  identifier: "internal_channel"
                }
              }
            }
          },
          internal_workflow_attributes: {
            identifier: "workflow_1"
          }
        }
      end

      it "successfully updates the config" do
        expect(service.call).to be true
        expect(service.errors).to be_empty

        config.reload
        expect(config.internal_release).to be_present
        expect(config.internal_workflow.name).to eq("Build and Deploy")
        expect(config.internal_release.submissions.count).to eq(1)
      end

      context "when disabling internal releases" do
        let(:params) do
          {
            internal_release_enabled: "false",
            internal_release_attributes: {
              submissions_attributes: {
                "0" => {
                  integrable_id: "variant_1",
                  submission_type: "internal"
                }
              }
            }
          }
        end

        it "marks internal release data for destruction" do
          expect(service.call).to be true
          config.reload
          expect(config.internal_release).to be_nil
        end
      end
    end

    context "when updating beta release settings" do
      let(:params) do
        {
          beta_release_submissions_enabled: "true",
          beta_release_attributes: {
            submissions_attributes: {
              "0" => {
                integrable_id: "variant_1",
                submission_type: "internal",
                number: "1",
                submission_external_attributes: {
                  identifier: "internal_channel"
                }
              }
            }
          }
        }
      end

      it "successfully updates beta release config" do
        expect(service.call).to be true
        expect(service.errors).to be_empty

        config.reload
        expect(config.beta_release).to be_present
        expect(config.beta_release.submissions.count).to eq(1)
      end

      context "when disabling beta releases" do
        let(:params) do
          {
            beta_release_submissions_enabled: "false",
            beta_release_attributes: {
              submissions_attributes: {
                "0" => {
                  integrable_id: "variant_1",
                  submission_type: "internal"
                }
              }
            }
          }
        end

        it "marks beta release submissions for destruction" do
          expect(service.call).to be true
          config.reload
          expect(config.beta_release&.submissions).to be_empty
        end
      end
    end

    context "when updating production release settings" do
      context "with Android platform" do
        let(:params) do
          {
            production_release_enabled: "true",
            production_release_attributes: {
              submissions_attributes: {
                "0" => {
                  rollout_enabled: "true",
                  rollout_stages: "0.2,0.5,1.0",
                  finish_rollout_in_next_release: "true"
                }
              }
            }
          }
        end

        it "successfully updates production release config with rollout data" do
          expect(service.call).to be true
          expect(service.errors).to be_empty

          config.reload
          submission = config.production_release.submissions.first
          expect(submission.rollout_stages).to eq([0.2, 0.5, 1.0])
          expect(submission.finish_rollout_in_next_release).to be true
        end

        context "when disabling rollout" do
          let(:params) do
            {
              production_release_enabled: "true",
              production_release_attributes: {
                submissions_attributes: {
                  "0" => {
                    rollout_enabled: "false",
                    rollout_stages: "0.2,0.5,1.0"
                  }
                }
              }
            }
          end

          it "clears rollout data" do
            expect(service.call).to be true

            config.reload
            submission = config.production_release.submissions.first
            expect(submission.rollout_stages).to be_empty
            expect(submission.finish_rollout_in_next_release).to be false
          end
        end
      end
    end

    context "when reordering submissions" do
      let!(:existing_config) { create(:release_platform_config) }
      let!(:internal_release) { create(:release_step_config, :internal, release_platform_config: existing_config) }
      let!(:internal_workflow) { create(:workflow_config, :internal, release_platform_config: existing_config) }
      let!(:submission1) { create(:submission_config, release_step_config: internal_release) }
      let!(:submission2) { create(:submission_config, release_step_config: internal_release) }

      let(:params) do
        {
          internal_release_enabled: "true",
          internal_release_attributes: {
            id: internal_release.id,
            submissions_attributes: {
              "0" => {
                id: submission2.id,
                number: "1"
              },
              "1" => {
                id: submission1.id,
                number: "2"
              }
            }
          }
        }
      end

      it "reorders submissions correctly" do
        service = described_class.new(existing_config, params, submission_types, ci_actions, release_platform)
        expect(service.call).to be true

        existing_config.reload
        expect(internal_release.submissions.order(:number).pluck(:id))
          .to eq([submission2.id, submission1.id])
      end
    end

    context "with invalid params" do
      let(:params) { {internal_release_enabled: nil} }

      it "returns false and adds errors" do
        expect(service.call).to be false
        expect(service.errors).not_to be_empty
      end
    end
  end
end
