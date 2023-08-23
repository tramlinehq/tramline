require "rails_helper"

describe Release do
  it "has a valid factory" do
    expect(create(:release)).to be_valid
  end

  describe ".create" do
    it "creates the release metadata with default locale" do
      run = create(:release)

      expect(run.release_metadata).to be_present
      expect(run.release_metadata.locale).to eq(ReleaseMetadata::DEFAULT_LOCALE)
      expect(run.release_metadata.release_notes).to eq(ReleaseMetadata::DEFAULT_RELEASE_NOTES)
    end

    it "creates the release platform run for android platform" do
      app = create(:app, :android)
      train = create(:train, app:)
      run = create(:release, train:)

      expect(run.release_platform_runs.size).to eq(1)
    end

    it "creates the release platform run for each release platform" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)
      run = create(:release, train:)

      expect(run.release_platform_runs.size).to eq(2)
    end
  end

  describe "#ready_to_be_finalized?" do
    it "is true when all release platform runs are finished" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)
      run = create(:release, train:)

      run.release_platform_runs.each do |run|
        run.update!(status: ReleasePlatformRun::STATES[:finished])
      end

      expect(run.ready_to_be_finalized?).to be(true)
    end

    it "is false when a release platform run is not finished" do
      app = create(:app, :cross_platform)
      train = create(:train, app:)
      run = create(:release, train:)

      run.release_platform_runs.first.update!(status: ReleasePlatformRun::STATES[:finished])

      expect(run.ready_to_be_finalized?).to be(false)
    end
  end

  describe "#create_release!" do
    let(:train) { create(:train, :active) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:step) { create(:step, release_platform:) }
    let(:release) { create(:release, train:) }
    let(:release_platform_run) { create(:release_platform_run, :on_track, release:, release_platform:) }

    it "saves a new tag with the base name" do
      allow_any_instance_of(GithubIntegration).to receive(:create_release!)
      commit = create(:commit, :without_trigger, release:)
      create(:step_run, release_platform_run:, commit:)

      release.create_release!
      expect(release.tag_name).to eq("v1.2.3")
    end

    it "saves base name + last commit sha" do
      raise_times(GithubIntegration, Installations::Errors::TaggedReleaseAlreadyExists, :create_release!, 1)
      commit = create(:commit, :without_trigger, release:)
      create(:step_run, release_platform_run:, commit:)

      release.create_release!
      expect(release.tag_name).to eq("v1.2.3-#{commit.short_sha}")
    end

    it "saves base name + last commit sha + time" do
      raise_times(GithubIntegration, Installations::Errors::TaggedReleaseAlreadyExists, :create_release!, 2)

      freeze_time do
        now = Time.now.to_i
        commit = create(:commit, :without_trigger, release:)
        create(:step_run, release_platform_run:, commit:)

        release.create_release!
        expect(release.tag_name).to eq("v1.2.3-#{commit.short_sha}-#{now}")
      end
    end
  end
end
