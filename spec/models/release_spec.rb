require "rails_helper"

describe Release do
  it "has a valid factory" do
    expect(create(:release)).to be_valid
  end

  describe "#set_version" do
    {"1.2.3" => {major: "2.0.0", minor: "1.3.0"},
     "1.2" => {major: "2.0", minor: "1.3"}}.each do |ver, expect|
      it "minor bump: sets the original_release_version to next version of the train" do
        train = create(:train, version_seeded_with: ver)
        run = build(:release, original_release_version: nil, train:)

        expect(run.original_release_version).to be_nil
        run.save!
        expect(run.original_release_version).to eq(expect[:minor])
      end

      it "major bump: sets the original_release_version to next version of the train" do
        train = create(:train, version_seeded_with: ver)
        run = build(:release, original_release_version: nil, train:)
        run.has_major_bump = true

        expect(run.original_release_version).to be_nil
        run.save!
        expect(run.original_release_version).to eq(expect[:major])
      end
    end

    context "when ongoing release" do
      {"1.2.3" => {major: "2.0.0", minor: "1.4.0"},
       "1.2" => {major: "2.0", minor: "1.4"}}.each do |ver, expect|
        it "minor bump: sets the original_release_version to next version of the ongoing release" do
          train = create(:train, version_seeded_with: ver)
          _ongoing_release = create(:release, :on_track, train:)
          run = build(:release, original_release_version: nil, train:)

          expect(run.original_release_version).to be_nil
          run.save!
          expect(run.original_release_version).to eq(expect[:minor])
        end

        it "major bump: sets the original_release_version to next version of the ongoing release" do
          train = create(:train, version_seeded_with: ver)
          _ongoing_release = create(:release, :on_track, train:)
          run = build(:release, original_release_version: nil, train:)
          run.has_major_bump = true

          expect(run.original_release_version).to be_nil
          run.save!
          expect(run.original_release_version).to eq(expect[:major])
        end
      end
    end
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

    context "when tag suffix" do
      let(:suffix) { "nightly" }
      let(:train) { create(:train, :active, tag_suffix: suffix) }

      it "saves a new tag with the base name + suffix" do
        allow_any_instance_of(GithubIntegration).to receive(:create_release!)
        commit = create(:commit, :without_trigger, release:)
        create(:step_run, release_platform_run:, commit:)

        release.create_release!
        expect(release.tag_name).to eq("v1.2.3-#{suffix}")
      end

      it "saves base name + suffix + last commit sha" do
        raise_times(GithubIntegration, Installations::Errors::TaggedReleaseAlreadyExists, :create_release!, 1)
        commit = create(:commit, :without_trigger, release:)
        create(:step_run, release_platform_run:, commit:)

        release.create_release!
        expect(release.tag_name).to eq("v1.2.3-#{suffix}-#{commit.short_sha}")
      end

      it "saves base name + suffix + last commit sha + time" do
        raise_times(GithubIntegration, Installations::Errors::TaggedReleaseAlreadyExists, :create_release!, 2)

        freeze_time do
          now = Time.now.to_i
          commit = create(:commit, :without_trigger, release:)
          create(:step_run, release_platform_run:, commit:)

          release.create_release!
          expect(release.tag_name).to eq("v1.2.3-#{suffix}-#{commit.short_sha}-#{now}")
        end
      end
    end

    context "when release tag disabled" do
      let(:train) { create(:train, :active, tag_releases: false) }

      it "does not create tag" do
        allow_any_instance_of(GithubIntegration).to receive(:create_release!)
        commit = create(:commit, :without_trigger, release:)
        create(:step_run, release_platform_run:, commit:)

        release.create_release!
        expect_any_instance_of(GithubIntegration).not_to receive(:create_release!)
        expect(release.tag_name).to be_nil
      end
    end
  end

  describe "#stop!" do
    it "updates the train version if partially finished" do
      train = create(:train, version_seeded_with: "9.59.3")
      run = create(:release, :partially_finished, train:)

      run.stop!
      train.reload

      expect(train.version_current).to eq("9.60.0")
    end

    it "does not update the train version if properly stopped" do
      train = create(:train, version_seeded_with: "9.59.3")
      run = create(:release, :post_release_started, train:)

      run.stop!
      train.reload

      expect(train.version_current).to eq("9.59.3")
    end
  end

  describe "#finish!" do
    it "updates the train version" do
      train = create(:train, version_seeded_with: "9.59.3")
      run = create(:release, :post_release_started, train:)

      run.finish!
      train.reload

      expect(train.version_current).to eq("9.60.0")
    end
  end
end
