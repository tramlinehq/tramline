require "rails_helper"

describe Queries::Releases do
  let(:app) { create(:app, :android) }
  let(:train) { create(:train, app:) }
  let(:release) { create(:release, train:) }
  let(:params) { OpenStruct.new(search_query: nil, limit: 10, offset: 0) }

  describe ".all" do
    subject(:query) { described_class.all(app: app, params: params) }

    context "with a release containing commits and pull requests" do
      before do
        create(:commit,
          release: release,
          message: "feat: add new feature",
          author_name: "John Doe",
          commit_hash: "abc1234",
          url: "https://github.com/org/repo/commit/abc1234")

        create(:pull_request,
          release: release,
          title: "Feature: Add new functionality",
          number: 123,
          state: "closed",
          url: "https://github.com/org/repo/pull/123",
          labels: %w[feature approved])
      end

      it "is query object" do
        expect(query).to be_an(Array)
        expect(query.first).to be_a(Queries::Release)
      end

      it "returns release info" do
        result = query.first

        expect(result.release_slug).to eq(release.slug)
        expect(result.release_status).to eq(release.status)
      end

      it "returns commit details" do
        result = query.first
        commit_result = result.commits.first

        expect(result.commits).to be_present
        expect(commit_result[:message]).to eq("feat: add new feature")
        expect(commit_result[:commit_hash]).to eq("abc1234")
        expect(commit_result[:author_name]).to eq("John Doe")
      end

      it "returns pull request details" do
        result = query.first
        pr_result = result.pull_requests.first

        expect(result.pull_requests).to be_present
        expect(pr_result[:title]).to eq("Feature: Add new functionality")
        expect(pr_result[:number]).to eq(123)
        expect(pr_result[:state]).to eq("closed")
        expect(pr_result[:labels]).to contain_exactly("feature", "approved")
      end
    end

    context "with search query" do
      before do
        # matching commit
        create(:commit, release: release, message: "feat: add search functionality")
        # non matching commit
        create(:commit, release: release, message: "chore: update dependencies")

        params.search_query = "search"
      end

      it "returns only releases with matching commits or pull requests" do
        expect(query.first.commits.pluck(:message)).not_to include("chore: update dependencies")
      end
    end

    context "with empty search query" do
      before do
        create(:commit, release: release, message: "feat: add search functionality")
        params.search_query = ""
      end

      it "returns all releases" do
        expect(query.first.commits).to be_present
      end
    end
  end

  describe ".count" do
    subject(:count_query) { described_class.count(app: app, params: params) }

    before do
      create_list(:commit, 3, release: release)
    end

    it "returns the correct count of releases" do
      expect(count_query).to eq(1)
    end
  end

  describe "pagination" do
    before do
      create_list(:release, 3, train: train).each do |rel|
        create(:commit, release: rel)
      end

      params.limit = 2
      params.offset = 1
    end

    it "respects limit and offset parameters" do
      results = described_class.all(app: app, params: params)
      expect(results.length).to eq(2)
    end
  end
end
