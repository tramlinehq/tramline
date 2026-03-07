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
end
