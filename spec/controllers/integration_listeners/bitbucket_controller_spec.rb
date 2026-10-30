# frozen_string_literal: true

require "rails_helper"

describe IntegrationListeners::BitbucketController do
  let(:organization) { create(:organization) }
  let(:app) { create(:app, :android, organization: organization) }
  let(:train) { create(:train, :active, app: app) }

  before do
    allow(Webhooks::ProcessPushWebhookJob).to receive(:perform_async)
    allow(Webhooks::ProcessPullRequestWebhookJob).to receive(:perform_async)
  end

  describe "#events" do
    context "when event is repo:push" do
      let(:push_payload) do
        {
          push: {
            changes: [
              {
                created: false,
                forced: false,
                closed: false,
                new: {
                  name: "release/1.0",
                  type: "branch",
                  target: {
                    type: "commit",
                    hash: "abc123",
                    date: "2024-01-01T00:00:00Z",
                    message: "fix: something",
                    author: {type: "author", raw: "Test <test@example.com>"},
                    links: {html: {href: "https://bitbucket.org/commit/abc123"}}
                  },
                  links: {html: {href: "https://bitbucket.org/branch/release"}}
                },
                commits: []
              }
            ]
          },
          repository: {name: "repo", full_name: "tramline/repo"}
        }
      end

      it "enqueues a ProcessPushWebhookJob and returns accepted" do
        request.headers["X-Event-Key"] = "repo:push"
        post :events, params: push_payload.merge(train_id: train.id)

        expect(response).to have_http_status(:accepted)
        expect(Webhooks::ProcessPushWebhookJob).to have_received(:perform_async).with(train.id, Hash)
      end
    end

    context "when event is pullrequest:created" do
      let(:pr_payload) do
        {
          repository: {name: "repo", full_name: "tramline/repo"},
          pullrequest: {
            id: 1,
            title: "Fix bug",
            description: "Fixes a bug",
            state: "OPEN",
            created_on: "2024-01-01T00:00:00Z",
            updated_on: "2024-01-01T00:00:00Z",
            merge_commit: nil,
            links: {html: {href: "https://bitbucket.org/tramline/repo/pull-requests/1"}},
            destination: {branch: {name: "release/1.0"}, commit: {hash: "def456"}},
            source: {branch: {name: "fix-bug"}, commit: {hash: "abc123"}}
          }
        }
      end

      it "enqueues a ProcessPullRequestWebhookJob and returns accepted" do
        request.headers["X-Event-Key"] = "pullrequest:created"
        post :events, params: pr_payload.merge(train_id: train.id)

        expect(response).to have_http_status(:accepted)
        expect(Webhooks::ProcessPullRequestWebhookJob).to have_received(:perform_async).with(train.id, Hash)
      end
    end

    %w[pullrequest:fulfilled pullrequest:rejected pullrequest:updated].each do |event|
      context "when event is #{event}" do
        let(:pr_payload) do
          {
            repository: {name: "repo", full_name: "tramline/repo"},
            pullrequest: {
              id: 1,
              title: "Fix bug",
              description: "Fixes a bug",
              state: "MERGED",
              created_on: "2024-01-01T00:00:00Z",
              updated_on: "2024-01-01T00:00:00Z",
              merge_commit: "abc123",
              links: {html: {href: "https://bitbucket.org/tramline/repo/pull-requests/1"}},
              destination: {branch: {name: "release/1.0"}, commit: {hash: "def456"}},
              source: {branch: {name: "fix-bug"}, commit: {hash: "abc123"}}
            }
          }
        end

        it "enqueues a ProcessPullRequestWebhookJob and returns accepted" do
          request.headers["X-Event-Key"] = event
          post :events, params: pr_payload.merge(train_id: train.id)

          expect(response).to have_http_status(:accepted)
          expect(Webhooks::ProcessPullRequestWebhookJob).to have_received(:perform_async).with(train.id, Hash)
        end
      end
    end

    context "when event is unknown" do
      it "returns ok and does not enqueue any jobs" do
        request.headers["X-Event-Key"] = "repo:fork"
        post :events, params: {train_id: train.id}

        expect(response).to have_http_status(:ok)
        expect(Webhooks::ProcessPushWebhookJob).not_to have_received(:perform_async)
        expect(Webhooks::ProcessPullRequestWebhookJob).not_to have_received(:perform_async)
      end
    end
  end

  describe "#callback" do
    using RefinedString

    let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }
    let(:valid_state) do
      {
        user_id: user.id,
        organization_id: organization.id,
        app_id: app.id,
        integration_category: "version_control",
        integration_provider: "BitbucketIntegration"
      }
    end
    let(:fresh_tokens) { OpenStruct.new(access_token: "fresh_access", refresh_token: "fresh_refresh") }

    before do
      app
      allow(controller).to receive(:current_user).and_return(user)
      allow(Installations::Bitbucket::Api).to receive(:oauth_access_token).and_return(fresh_tokens)
    end

    context "when creating a new integration" do
      let(:params) { {state: valid_state.to_json.encode, code: "oauth_code_123"} }

      it "creates a connected integration and redirects with success message" do
        expect {
          get :callback, params: params
        }.to change(Integration, :count).by(1)

        expect(Integration.last).to be_connected
        expect(response).to redirect_to(app_path(app))
        expect(flash[:notice]).to eq("Integration was successfully created.")
      end

      it "exchanges the code once and stores the tokens" do
        get :callback, params: params

        expect(Installations::Bitbucket::Api).to have_received(:oauth_access_token).with("oauth_code_123", anything).once
        providable = Integration.last.providable
        expect(providable.oauth_access_token).to eq("fresh_access")
        expect(providable.oauth_refresh_token).to eq("fresh_refresh")
      end

      it "does not create the integration when the code exchange returns no tokens" do
        allow(Installations::Bitbucket::Api).to receive(:oauth_access_token).and_return(OpenStruct.new)

        expect {
          get :callback, params: params
        }.not_to change(Integration, :count)

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:alert]).to be_present
      end
    end

    context "when re-authenticating an existing integration" do
      let(:existing_integration) do
        create(:integration, :with_bitbucket, integrable: app).tap { |integration| integration.update!(status: "needs_reauth") }
      end
      let(:params) do
        {state: valid_state.merge(integration_id: existing_integration.id).to_json.encode, code: "oauth_code_456"}
      end

      it "reconnects the existing integration and redirects with success message" do
        existing_integration

        expect {
          get :callback, params: params
        }.not_to change(Integration, :count)

        expect(existing_integration.reload).to be_connected
        expect(response).to redirect_to(app_path(app))
        expect(flash[:notice]).to eq("Integration was successfully re-authenticated.")
      end

      it "replaces the stored tokens with the ones from the new code" do
        get :callback, params: params

        expect(Installations::Bitbucket::Api).to have_received(:oauth_access_token).with("oauth_code_456", anything).once
        providable = existing_integration.providable.reload
        expect(providable.oauth_access_token).to eq("fresh_access")
        expect(providable.oauth_refresh_token).to eq("fresh_refresh")
      end

      it "keeps the integration needing re-authorization when the code exchange returns no tokens" do
        old_access_token = existing_integration.providable.oauth_access_token
        allow(Installations::Bitbucket::Api).to receive(:oauth_access_token).and_return(OpenStruct.new)

        get :callback, params: params

        expect(existing_integration.reload).to be_needs_reauth
        expect(existing_integration.providable.reload.oauth_access_token).to eq(old_access_token)
        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:alert]).to be_present
      end
    end
  end
end
