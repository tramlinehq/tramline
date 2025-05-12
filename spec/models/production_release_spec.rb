# frozen_string_literal: true

require "rails_helper"

describe ProductionRelease do
  using RefinedString

  describe "#version_bump_required?" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:current_prod_release_version) { "1.2.0" }
    let(:build) { create(:build, release_platform_run:) }

    it "is false when release platform run has a higher release version" do
      build.update! version_name: current_prod_release_version
      production_release = create(:production_release, :active, build:, release_platform_run:)
      bumped = current_prod_release_version.to_semverish.bump!(:patch).to_s
      release_platform_run.update!(release_version: bumped)
      expect(production_release.version_bump_required?).to be false
    end

    context "when release platform run has the same release version" do
      before do
        release_platform_run.update!(release_version: current_prod_release_version)
      end

      it "is true when production release is active" do
        production_release = create(:production_release, :active, build:, release_platform_run:)
        expect(production_release.version_bump_required?).to be(true)
      end

      it "is false when store submission is in progress" do
        production_release = create(:production_release, :inflight, build:, release_platform_run:)
        create(:play_store_submission, :created, parent_release: production_release)
        expect(production_release.version_bump_required?).to be(false)
      end

      it "is false when store submission is finished and version bump is not required for the store submission" do
        production_release = create(:production_release, :inflight, build:, release_platform_run:)
        create(:play_store_submission, :prepared, parent_release: production_release)
        expect(production_release.version_bump_required?).to be(false)
      end

      it "is true when store submission is finished and version bump is required for the store submission" do
        production_release = create(:production_release, :inflight, build:, release_platform_run:)
        sub = create(:app_store_submission, :approved, parent_release: production_release)
        create(:store_rollout, :app_store, :completed, store_submission: sub, release_platform_run:)
        expect(production_release.version_bump_required?).to be(true)
      end
    end
  end

  describe "#create_tag!" do
    let(:train) { create(:train) }
    let(:release) { create(:release, train:) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:, release:) }
    let(:commit) { create(:commit, release:) }
    let(:build) { create(:build, release_platform_run:, commit:) }
    let(:tag_exists_error) { Installations::Error.new("Could not tag", reason: :tag_reference_already_exists) }

    it "saves a new tag with the base name" do
      production_release = create(:production_release, :inflight, build:, release_platform_run:)
      allow(train).to receive(:create_tag!)

      production_release.create_tag!(commit.commit_hash)

      expect(train).to have_received(:create_tag!).with("v1.2.3", commit.commit_hash)
    end

    it "saves base name + last commit sha" do
      production_release = create(:production_release, :inflight, build:, release_platform_run:)
      raise_times(GithubIntegration, tag_exists_error, :create_tag!, 1)

      production_release.create_tag!(commit.commit_hash)

      expect(production_release.tag_name).to eq("v1.2.3-#{commit.short_sha}")
    end

    it "saves base name + last commit sha + time" do
      production_release = create(:production_release, :inflight, build:, release_platform_run:)
      raise_times(GithubIntegration, tag_exists_error, :create_tag!, 2)

      freeze_time do
        now = Time.now.to_i
        production_release.create_tag!(commit.commit_hash)

        expect(production_release.tag_name).to eq("v1.2.3-#{commit.short_sha}-#{now}")
      end
    end

    it "adds platform names for cross-platform apps" do
      train.app.update!(platform: "cross_platform")
      train.update!(tag_store_releases: true, tag_store_releases_with_platform_names: true)
      production_release = create(:production_release, :inflight, build:, release_platform_run:)
      allow(train).to receive(:create_tag!)

      production_release.create_tag!(commit.commit_hash)

      expect(train).to have_received(:create_tag!).with("v1.2.3-android", commit.commit_hash)
    end

    context "when rollout completes" do
      it "creates a tag for the production release" do
        production_release = create(:production_release, :inflight, build:, release_platform_run:, tag_name: nil)
        create(:store_rollout,
          :play_store,
          :started,
          is_staged_rollout: false,
          store_submission: create(:play_store_submission, :prepared, parent_release: production_release),
          release_platform_run:)
        allow(ProductionReleases::CreateTagJob).to receive(:perform_async)

        production_release.rollout_complete!(nil)

        expect(ProductionReleases::CreateTagJob).to have_received(:perform_async).with(production_release.id)
      end

      it "does not create a tag for the production release if tag name is already set (and it is staged)" do
        production_release = create(:production_release, :inflight, build:, release_platform_run:, tag_name: "v1")
        create(:store_rollout,
          :play_store,
          :started,
          is_staged_rollout: true,
          store_submission: create(:play_store_submission, :prepared, parent_release: production_release),
          release_platform_run:)
        allow(ProductionReleases::CreateTagJob).to receive(:perform_async)

        production_release.rollout_complete!(nil)

        expect(ProductionReleases::CreateTagJob).not_to have_received(:perform_async)
      end
    end

    context "when rollout starts" do
      it "creates a tag for the production release when rollout starts" do
        production_release = create(:production_release, :inflight, build:, release_platform_run:)
        create(:store_rollout,
          :play_store,
          :started,
          store_submission: create(:play_store_submission, :prepared, parent_release: production_release),
          release_platform_run:)
        allow(ProductionReleases::CreateTagJob).to receive(:perform_async)

        production_release.rollout_started!

        expect(ProductionReleases::CreateTagJob).to have_received(:perform_async).with(production_release.id)
      end

      it "does not create a tag for the production release if tag name is already set" do
        production_release = create(:production_release, :inflight, build:, release_platform_run:, tag_name: "v1")
        create(:store_rollout,
          :play_store,
          :started,
          store_submission: create(:play_store_submission, :prepared, parent_release: production_release),
          release_platform_run:)
        allow(ProductionReleases::CreateTagJob).to receive(:perform_async)

        production_release.rollout_started!

        expect(ProductionReleases::CreateTagJob).not_to have_received(:perform_async)
      end
    end
  end

  describe "#create_vcs_release!" do
    let(:train) { create(:train) }
    let(:release) { create(:release, train:) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:, release:) }
    let(:commit) { create(:commit, release:) }
    let(:build) { create(:build, release_platform_run:, commit:) }
    let(:tag_exists_error) { Installations::Error.new("Could not tag", reason: :tag_reference_already_exists) }

    it "saves a new tag (with vcs release) with the base name" do
      production_release = create(:production_release, :inflight, build:, release_platform_run:)
      allow(train).to receive(:create_vcs_release!)

      production_release.create_vcs_release!(commit.commit_hash, anything)

      expect(train).to have_received(:create_vcs_release!).with(commit.commit_hash, "v1.2.3", anything)
    end
  end

  describe "#rollout_started!" do
    let(:train) { create(:train, tag_store_releases: true, tag_store_releases_with_platform_names: true) }
    let(:release) { create(:release, train:) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:, release:) }
    let(:commit) { create(:commit, release:) }
    let(:build) { create(:build, release_platform_run:, commit:) }
    let(:production_release) { create(:production_release, :inflight, build:, release_platform_run:) }

    before do
      create(:store_rollout,
        :play_store,
        :started,
        store_submission: create(:play_store_submission, :prepared, parent_release: production_release),
        release_platform_run:)
    end

    it "marks the inflight production release as active" do
      production_release.rollout_started!

      expect(production_release.active?).to be(true)
    end
  end

  describe "#fetch_health_data!" do
    let(:train) { create(:train, tag_store_releases: true, tag_store_releases_with_platform_names: true) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:monitoring_api_dbl) { instance_double(Installations::Crashlytics::Api) }

    it "fetches health data from the monitoring provider" do
      integration = create(:integration, :with_crashlytics)
      monitoring_provider = integration.providable
      create_production_rollout_tree(
        train,
        release_platform,
        release_traits: [:on_track],
        run_status: :on_track,
        parent_release_status: :active,
        rollout_status: :started,
        skip_rollout: false
      ) => { release_platform:, release:, production_release:, store_rollout: }
      allow(production_release).to receive(:monitoring_provider).and_return(monitoring_provider)
      allow(monitoring_provider).to receive(:installation).and_return(monitoring_api_dbl)
      allow(monitoring_provider).to receive(:find_release)

      production_release.fetch_health_data!

      expect(monitoring_provider).to have_received(:find_release).with(release_platform.platform, release.release_version, production_release.build.build_number, store_rollout.created_at)
    end

    it "does not fetch health data if app has monitoring disabled" do
      integration = create(:integration, :with_crashlytics)
      monitoring_provider = integration.providable
      create_production_rollout_tree(
        train,
        release_platform,
        release_traits: [:on_track],
        run_status: :on_track,
        parent_release_status: :active,
        rollout_status: :started,
        skip_rollout: false
      ) => { release_platform:, release:, production_release:, store_rollout: }
      allow(production_release).to receive(:monitoring_provider).and_return(monitoring_provider)
      allow(monitoring_provider).to receive(:installation).and_return(monitoring_api_dbl)
      allow(monitoring_provider).to receive(:find_release)

      Flipper.enable_actor(:monitoring_disabled, train.app)
      production_release.fetch_health_data!

      expect(monitoring_provider).not_to have_received(:find_release).with(release_platform.platform, release.release_version, production_release.build.build_number, store_rollout.created_at)
    end
  end
end
