require "rails_helper"

RSpec.describe Queries::Releases do
  let(:app) { create(:app, :android) }
  let(:train) { create(:train, app:) }
  let(:release) { create(:release, train:) }
  let(:params) { OpenStruct.new(search_query: nil, limit: 10, offset: 0) }

  describe ".all" do
    subject { described_class.all(app: app, params: params) }

    context "with a release containing commits and pull requests" do
      let!(:commit) do
        create(:commit,
          release: release,
          message: "feat: add new feature",
          author_name: "John Doe",
          commit_hash: "abc1234",
          url: "https://github.com/org/repo/commit/abc1234")
      end

      let!(:pull_request) do
        create(:pull_request,
          release: release,
          title: "Feature: Add new functionality",
          number: 123,
          state: "closed",
          url: "https://github.com/org/repo/pull/123",
          labels: ["feature", "approved"])
      end

      it "returns releases with their associated commits and pull requests" do
        results = subject
        expect(results).to be_an(Array)
        expect(results.first).to be_a(Queries::Release)

        result = results.first
        expect(result.release_slug).to eq(release.slug)
        expect(result.release_status).to eq(release.status)

        # Check commits
        expect(result.commits).to be_present
        commit_result = result.commits.first
        expect(commit_result[:message]).to eq("feat: add new feature")
        expect(commit_result[:commit_hash]).to eq("abc1234")
        expect(commit_result[:author_name]).to eq("John Doe")

        # Check pull requests
        expect(result.pull_requests).to be_present
        pr_result = result.pull_requests.first
        expect(pr_result[:title]).to eq("Feature: Add new functionality")
        expect(pr_result[:number]).to eq(123)
        expect(pr_result[:state]).to eq("closed")
        expect(pr_result[:labels]).to contain_exactly("feature", "approved")
      end
    end

    context "with search query" do
      let!(:matching_commit) do
        create(:commit, release: release, message: "feat: add search functionality")
      end

      let!(:non_matching_commit) do
        create(:commit, release: release, message: "chore: update dependencies")
      end

      before do
        params.search_query = "search"
      end

      it "returns only releases with matching commits or pull requests" do
        results = subject
        expect(results.first.commits.map { |c| c[:message] })
          .to include("feat: add <mark>search</mark> functionality")
        expect(results.first.commits.map { |c| c[:message] })
          .not_to include("chore: update dependencies")
      end
    end

    context "with empty search query" do
      before do
        create(:commit, release: release, message: "feat: add search functionality")
        params.search_query = ""
      end

      it "returns all releases" do
        results = subject
        expect(results).to be_present
        expect(results.first.commits).to be_present
      end
    end
  end

  describe ".count" do
    subject { described_class.count(app: app, params: params) }

    before do
      create_list(:commit, 3, release: release)
    end

    it "returns the correct count of releases" do
      expect(subject).to eq(1)
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
