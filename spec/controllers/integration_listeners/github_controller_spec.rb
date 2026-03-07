# frozen_string_literal: true

require "rails_helper"

describe IntegrationListeners::GithubController do
  let(:organization) { create(:organization) }
  let(:app) { create(:app, :android, organization: organization) }
  let(:train) { create(:train, :active, app: app) }

  before do
    allow(Webhooks::ProcessPushWebhookJob).to receive(:perform_async)
    allow(Webhooks::ProcessPullRequestWebhookJob).to receive(:perform_async)
  end

  describe "#events" do
    context "when event is push" do
      let(:push_payload) do
        {
          ref: "refs/heads/release/1.0",
          repository: {full_name: "tramline/repo", name: "repo"},
          head_commit: {
            id: "abc123",
            message: "fix: something",
            timestamp: "2024-01-01T00:00:00Z",
            url: "https://github.com/tramline/repo/commit/abc123",
            author: {name: "Test", email: "test@example.com", username: "test"},
            committer: {name: "Test", email: "test@example.com", username: "test"}
          },
          commits: []
        }
      end

      it "enqueues a ProcessPushWebhookJob and returns accepted" do
        request.headers["HTTP_X_GITHUB_EVENT"] = "push"
        post :events, params: push_payload.merge(train_id: train.id)

        expect(response).to have_http_status(:accepted)
        expect(Webhooks::ProcessPushWebhookJob).to have_received(:perform_async).with(train.id, Hash)
      end
    end

    context "when event is pull_request" do
      let(:pr_payload) do
        {
          repository: {full_name: "tramline/repo", name: "repo"},
          pull_request: {
            number: 1,
            title: "Fix bug",
            body: "Fixes a bug",
            url: "https://api.github.com/repos/tramline/repo/pulls/1",
            state: "open",
            created_at: "2024-01-01T00:00:00Z",
            closed_at: nil,
            id: 12345,
            merge_commit_sha: "def456",
            html_url: "https://github.com/tramline/repo/pull/1",
            base: {ref: "release/1.0"},
            head: {ref: "fix-bug", repo: {full_name: "tramline/repo"}},
            labels: []
          }
        }
      end

      it "enqueues a ProcessPullRequestWebhookJob and returns accepted" do
        request.headers["HTTP_X_GITHUB_EVENT"] = "pull_request"
        post :events, params: pr_payload.merge(train_id: train.id)

        expect(response).to have_http_status(:accepted)
        expect(Webhooks::ProcessPullRequestWebhookJob).to have_received(:perform_async).with(train.id, Hash)
      end
    end

    context "when event is ping" do
      it "returns accepted" do
        request.headers["HTTP_X_GITHUB_EVENT"] = "ping"
        post :events, params: {train_id: train.id}

        expect(response).to have_http_status(:accepted)
      end

      it "does not enqueue any jobs" do
        request.headers["HTTP_X_GITHUB_EVENT"] = "ping"
        post :events, params: {train_id: train.id}

        expect(Webhooks::ProcessPushWebhookJob).not_to have_received(:perform_async)
        expect(Webhooks::ProcessPullRequestWebhookJob).not_to have_received(:perform_async)
      end
    end

    context "when event is unknown" do
      it "returns ok" do
        request.headers["HTTP_X_GITHUB_EVENT"] = "installation"
        post :events, params: {train_id: train.id}

        expect(response).to have_http_status(:ok)
      end

      it "does not enqueue any jobs" do
        request.headers["HTTP_X_GITHUB_EVENT"] = "installation"
        post :events, params: {train_id: train.id}

        expect(Webhooks::ProcessPushWebhookJob).not_to have_received(:perform_async)
        expect(Webhooks::ProcessPullRequestWebhookJob).not_to have_received(:perform_async)
      end
    end
  end
end
