# frozen_string_literal: true

require "rails_helper"

describe PreProdRelease do
  describe "#trigger_submissions!" do
    let(:pre_prod_release) { create(:internal_release) }
    let(:workflow_run) { create(:workflow_run, triggering_release: pre_prod_release) }

    it "triggers the first submission" do
      build = create(:build, workflow_run:)
      pre_prod_release.trigger_submissions!
      expect(pre_prod_release.store_submissions.count).to eq(1)
      expect(pre_prod_release.store_submissions.sole.build).to eq(build)
      expect(pre_prod_release.store_submissions.sole.preprocessing?).to be true
    end
  end

  describe "#rollout_complete!" do
    let(:pre_prod_release) { create(:internal_release) }
    let(:workflow_run) { create(:workflow_run, triggering_release: pre_prod_release) }
    let(:build) { create(:build, workflow_run:) }
    let(:submission) { create(:play_store_submission, parent_release: pre_prod_release, build:, sequence_number: 1) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(PlayStoreSubmission).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:find_build).and_return(true)
    end

    it "triggers the next submission" do
      pre_prod_release.rollout_complete!(submission)
      expect(pre_prod_release.store_submissions.count).to eq(2)
      expect(pre_prod_release.store_submissions.find_by(sequence_number: 2).preprocessing?).to be true
    end

    it "finishes the release if there are no more submissions" do
      next_submission = create(:play_store_submission, parent_release: pre_prod_release, build:, sequence_number: 2)
      pre_prod_release.rollout_complete!(next_submission)
      expect(pre_prod_release.finished?).to be true
    end

    context "when auto promote is disabled" do
      let(:release_platform_run) { create(:release_platform_run) }
      let(:config) {
        {auto_promote: true,
         submissions: [
           {
             number: 1,
             submission_type: "PlayStoreSubmission",
             submission_config: {id: :internal, name: "internal testing"},
             rollout_config: {enabled: false},
             auto_promote: true,
             integrable_id: release_platform_run.app.id,
             integrable_type: "App"
           },
           {
             number: 2,
             submission_type: "PlayStoreSubmission",
             submission_config: {id: :alpha, name: "closed testing"},
             rollout_config: {enabled: true, stages: [10, 100]},
             auto_promote: false,
             integrable_id: release_platform_run.app.id,
             integrable_type: "App"
           }
         ]}
      }
      let(:pre_prod_release) { create(:pre_prod_release, release_platform_run:, config:) }

      it "does not trigger the next submission if auto_promote is false" do
        pre_prod_release.rollout_complete!(submission)
        expect(pre_prod_release.store_submissions.count).to eq(2)
        expect(pre_prod_release.store_submissions.find_by(sequence_number: 2).created?).to be true
      end
    end
  end

  describe "#changes_since_previous" do
    let(:release) { create(:release, :with_no_platform_runs) }
    let(:release_platform_run) { create(:release_platform_run, release:) }

    it "returns the release changelog when its the first pre prod release" do
      release_changelog = create(:release_changelog, release:)
      first_release = create(:beta_release, release_platform_run:)
      result = first_release.changes_since_previous
      expect(result).to eq(release_changelog.commit_messages(true))
    end

    it "returns the release changelog and the commits on the release branch when the previous releases are unfinished" do
      release_changelog = create(:release_changelog, release:)
      first_commit = create(:commit, release:)
      _first_release = create(:beta_release, :stale, release_platform_run:, commit: first_commit)
      second_commit = create(:commit, release:)
      second_release = create(:beta_release, release_platform_run:, commit: second_commit)
      result = second_release.changes_since_previous
      expect(result).to contain_exactly(first_commit.message, second_commit.message, *release_changelog.commit_messages(true))
    end

    it "returns the release changelog and all commits applied to the release branch when there are no previous releases" do
      release_changelog = create(:release_changelog, release:)
      first_commit = create(:commit, release:)
      second_commit = create(:commit, release:)
      first_release = create(:beta_release, :stale, release_platform_run:, commit: second_commit)
      result = first_release.changes_since_previous
      expect(result).to contain_exactly(first_commit.message, second_commit.message, *release_changelog.commit_messages(true))
    end

    it "returns the difference between the previously successful release and the current release" do
      _release_changelog = create(:release_changelog, release:)
      first_commit = create(:commit, release:)
      first_release = create(:beta_release, :finished, release_platform_run:, commit: first_commit)
      second_commit = create(:commit, release:)
      second_release = create(:beta_release, release_platform_run:, commit: second_commit, previous: first_release)
      result = second_release.changes_since_previous
      expect(result).to contain_exactly(second_commit.message)
    end

    it "returns the difference between the previously successful release and the current release when there are multiple commits" do
      _release_changelog = create(:release_changelog, release:)
      first_commit = create(:commit, release:)
      first_release = create(:beta_release, :finished, release_platform_run:, commit: first_commit)
      second_commit = create(:commit, release:)
      _second_release = create(:beta_release, :stale, release_platform_run:, commit: second_commit, previous: first_release)
      third_commit = create(:commit, release:)
      third_release = create(:beta_release, release_platform_run:, commit: third_commit, previous: first_release)
      result = third_release.changes_since_previous
      expect(result).to contain_exactly(second_commit.message, third_commit.message)
    end
  end
end
