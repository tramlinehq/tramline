# frozen_string_literal: true

require "rails_helper"

describe IntegrationListeners::GitlabController do
  using RefinedString

  let(:organization) { create(:organization) }
  let(:app) { create(:app, platform: :android, organization: organization) }
  let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }
  let(:valid_state) do
    {
      user_id: user.id,
      organization_id: organization.id,
      app_id: app.id,
      integration_category: "version_control",
      integration_provider: "GitlabIntegration"
    }
  end

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow_any_instance_of(Integration).to receive(:set_metadata!)
    allow_any_instance_of(GitlabIntegration).to receive(:complete_access).and_return(true)
    allow_any_instance_of(GitlabIntegration).to receive(:repos).and_return([{id: 1, name: "test-repo"}])
  end

  describe "#events" do
    let(:train) { create(:train, :active, app: app) }

    before do
      allow(Webhooks::ProcessPushWebhookJob).to receive(:perform_async)
      allow(Webhooks::ProcessPullRequestWebhookJob).to receive(:perform_async)
    end

    context "when event is push" do
      let(:push_payload) do
        {
          object_kind: "push",
          ref: "refs/heads/release/1.0",
          checkout_sha: "abc123",
          project: {path_with_namespace: "tramline/repo"},
          commits: [
            {id: "abc123", message: "fix: something", title: "fix", timestamp: "2024-01-01T00:00:00Z", url: "https://gitlab.com/commit/abc123", author: {name: "Test", email: "test@example.com"}}
          ]
        }
      end

      it "enqueues a ProcessPushWebhookJob and returns accepted" do
        post :events, params: push_payload.merge(train_id: train.id)

        expect(response).to have_http_status(:accepted)
        expect(Webhooks::ProcessPushWebhookJob).to have_received(:perform_async).with(train.id, Hash)
      end
    end

    context "when event is merge_request" do
      let(:mr_payload) do
        {
          object_kind: "merge_request",
          project: {path_with_namespace: "tramline/repo"},
          object_attributes: {
            id: 1,
            iid: 10,
            target_branch: "release/1.0",
            source_branch: "fix-bug",
            state: "opened",
            action: "open",
            title: "Fix bug",
            description: "Fixes a bug",
            url: "https://gitlab.com/tramline/repo/-/merge_requests/10",
            created_at: "2024-01-01T00:00:00Z",
            updated_at: "2024-01-01T00:00:00Z",
            last_commit: {id: "abc123"}
          }
        }
      end

      it "enqueues a ProcessPullRequestWebhookJob and returns accepted" do
        post :events, params: mr_payload.merge(train_id: train.id)

        expect(response).to have_http_status(:accepted)
        expect(Webhooks::ProcessPullRequestWebhookJob).to have_received(:perform_async).with(train.id, Hash)
      end
    end

    context "when event is ping" do
      it "returns accepted and does not enqueue any jobs" do
        post :events, params: {object_kind: "ping", train_id: train.id}

        expect(response).to have_http_status(:accepted)
        expect(Webhooks::ProcessPushWebhookJob).not_to have_received(:perform_async)
        expect(Webhooks::ProcessPullRequestWebhookJob).not_to have_received(:perform_async)
      end
    end

    context "when event is unknown" do
      it "returns ok and does not enqueue any jobs" do
        post :events, params: {object_kind: "note", train_id: train.id}

        expect(response).to have_http_status(:ok)
        expect(Webhooks::ProcessPushWebhookJob).not_to have_received(:perform_async)
        expect(Webhooks::ProcessPullRequestWebhookJob).not_to have_received(:perform_async)
      end
    end
  end

  describe "#callback" do
    let(:params) do
      {
        state: valid_state.to_json.encode,
        code: "oauth_code_123"
      }
    end

    context "when creating new integration (no existing integration)" do
      it "creates new integration and redirects with success message" do
        expect {
          get :callback, params: params
        }.to change(Integration, :count).by(1)

        expect(response).to redirect_to(app_path(app))
        expect(flash[:notice]).to eq("Integration was successfully created.")
      end

      it "sets correct integration attributes" do
        get :callback, params: params

        integration = Integration.last
        expect(integration.integrable).to eq(app)
        expect(integration.status).to eq("connected")
        expect(integration.category).to eq("version_control")
        expect(integration.providable_type).to eq("GitlabIntegration")
      end
    end

    context "when re-authenticating existing integration" do
      let(:existing_integration) do
        create(:integration,
          category: "version_control",
          integrable: app,
          providable: create(:gitlab_integration, :without_callbacks_and_validations)).tap do |i|
          i.update!(status: "needs_reauth")
        end
      end
      let(:reauth_params) do
        state = valid_state.merge(integration_id: existing_integration.id).to_json.encode

        {
          state: state,
          code: "oauth_code_456"
        }
      end

      it "updates existing integration and redirects with success message" do
        existing_integration # Force creation

        expect {
          get :callback, params: reauth_params
        }.not_to change(Integration, :count)

        existing_integration.reload
        expect(existing_integration.status).to eq("connected")
        expect(response).to redirect_to(app_path(app))
        expect(flash[:notice]).to eq("Integration was successfully re-authenticated.")
      end

      context "when existing integration not found" do
        let(:reauth_params) do
          state = valid_state.merge(integration_id: "non-existent-id").to_json.encode
          {
            state: state,
            code: "oauth_code_456"
          }
        end

        it "creates new integration instead" do
          expect {
            get :callback, params: reauth_params
          }.to change(Integration, :count).by(1)

          expect(response).to redirect_to(app_path(app))
          expect(flash[:notice]).to eq("Integration was successfully created.")
        end
      end
    end
  end
end
