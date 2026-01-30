require "rails_helper"

describe RefreshReportsJob do
  let(:train) { create(:train) }
  let(:release) { create(:release, train:) }

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
  end

  it "warms up the release breakdown and train devops report query caches" do
    allow(Queries::ReleaseBreakdown).to receive(:warm)
    allow(Queries::DevopsReport).to receive(:warm)

    described_class.new.perform(release.id)

    expect(Queries::ReleaseBreakdown).to have_received(:warm).once
    expect(Queries::DevopsReport).to have_received(:warm).once
  end

  describe "release breakdown query caching" do
    before do
      allow(Queries::ReleaseBreakdown).to receive(:warm).and_call_original
      allow(Queries::DevopsReport).to receive(:warm)
    end

    Queries::ReleaseBreakdown::PARTS.each do |part|
      it "writes the #{part} key to the release breakdown query cache" do
        expect do
          described_class.new.perform(release.id)
        end.to change {
          Rails.cache.exist?("release/#{release.id}/#{part}")
        }.from(false).to(true)
      end
    end
  end

  describe "devops report query caching" do
    before do
      allow(Queries::ReleaseBreakdown).to receive(:warm)
      allow(Queries::DevopsReport).to receive(:warm).and_call_original
    end

    it "writes to the train devops report query cache" do
      expect do
        described_class.new.perform(release.id)
      end.to change {
        Rails.cache.exist?("train/#{train.id}/queries/devops_report")
      }.from(false).to(true)
    end

    context "when train follows semver versioning" do
      describe "when previous releases were partial semver" do
        it "caches the report elements in semantic order of releases when current release has a partial semver version" do
          rel1 = create(:release, :finished, train:, completed_at: 7.days.ago)
          rel1.release_platform_runs.each { |run| run.update!(release_version: "1.1") }

          rel2 = create(:release, :finished, train:, completed_at: 5.days.ago)
          rel2.release_platform_runs.each { |run| run.update!(release_version: "1.2") }

          release.update!(status: :finished, completed_at: 3.days.ago)
          release.release_platform_runs.each { |run| run.update!(release_version: "1.3") }

          described_class.new.perform(release.id)

          cached_report = Rails.cache.read("train/#{train.id}/queries/devops_report")
          expect(cached_report[:duration].keys).to eq(["1.1", "1.2", "1.3"])
          expect(cached_report[:patch_fixes].keys).to eq(["1.1", "1.2", "1.3"])
          expect(cached_report[:hotfixes].keys).to eq(["1.1", "1.2", "1.3"])
          expect(cached_report[:time_in_phases].keys).to eq(["1.1", "1.2", "1.3"])
          expect(cached_report[:stability_contributors].keys).to eq(["1.1", "1.2", "1.3"])
          expect(cached_report[:contributors].keys).to eq(["1.1", "1.2", "1.3"])
        end

        it "caches the report elements in semantic order of releases when current release has a proper semver version" do
          rel1 = create(:release, :finished, train:, completed_at: 7.days.ago)
          rel1.release_platform_runs.each { |run| run.update!(release_version: "1.1") }

          rel2 = create(:release, :finished, train:, completed_at: 5.days.ago)
          rel2.release_platform_runs.each { |run| run.update!(release_version: "1.2") }

          release.update!(status: :finished, completed_at: 3.days.ago)
          release.release_platform_runs.each { |run| run.update!(release_version: "1.2.1") }

          described_class.new.perform(release.id)

          cached_report = Rails.cache.read("train/#{train.id}/queries/devops_report")
          expect(cached_report[:duration].keys).to eq(["1.1", "1.2", "1.2.1"])
          expect(cached_report[:patch_fixes].keys).to eq(["1.1", "1.2", "1.2.1"])
          expect(cached_report[:hotfixes].keys).to eq(["1.1", "1.2", "1.2.1"])
          expect(cached_report[:time_in_phases].keys).to eq(["1.1", "1.2", "1.2.1"])
          expect(cached_report[:stability_contributors].keys).to eq(["1.1", "1.2", "1.2.1"])
          expect(cached_report[:contributors].keys).to eq(["1.1", "1.2", "1.2.1"])
        end
      end

      it "caches the report elements in semantic order of releases when current release has a proper semver version and previous releases were proper semver" do
        rel1 = create(:release, :finished, train:, completed_at: 7.days.ago)
        rel1.release_platform_runs.each { |run| run.update!(release_version: "1.2.0") }

        rel2 = create(:release, :finished, train:, completed_at: 5.days.ago)
        rel2.release_platform_runs.each { |run| run.update!(release_version: "1.2.1") }

        release.update!(status: :finished, completed_at: 3.days.ago)
        release.release_platform_runs.each { |run| run.update!(release_version: "1.2.2") }
        described_class.new.perform(release.id)

        cached_report = Rails.cache.read("train/#{train.id}/queries/devops_report")

        expect(cached_report[:duration].keys).to eq(["1.2.0", "1.2.1", "1.2.2"])
        expect(cached_report[:patch_fixes].keys).to eq(["1.2.0", "1.2.1", "1.2.2"])
        expect(cached_report[:hotfixes].keys).to eq(["1.2.0", "1.2.1", "1.2.2"])
        expect(cached_report[:time_in_phases].keys).to eq(["1.2.0", "1.2.1", "1.2.2"])
        expect(cached_report[:stability_contributors].keys).to eq(["1.2.0", "1.2.1", "1.2.2"])
        expect(cached_report[:contributors].keys).to eq(["1.2.0", "1.2.1", "1.2.2"])
      end
    end

    it "caches the report elements in semantic order of releases when the train follows calver versioning" do
      allow(Queries::ReleaseBreakdown).to receive(:warm)
      allow(Queries::DevopsReport).to receive(:warm).and_call_original

      train.update!(versioning_strategy: :calver)

      rel1 = create(:release, :finished, train:, completed_at: 7.days.ago)
      rel1.release_platform_runs.each { |run| run.update!(release_version: "2015.12.01") }

      rel2 = create(:release, :finished, train:, completed_at: 5.days.ago)
      rel2.release_platform_runs.each { |run| run.update!(release_version: "2015.12.02") }

      release.update!(status: :finished, completed_at: 3.days.ago)
      release.release_platform_runs.each { |run| run.update!(release_version: "2015.12.0201") }

      described_class.new.perform(release.id)

      cached_report = Rails.cache.read("train/#{train.id}/queries/devops_report")

      expect(cached_report[:duration].keys).to eq(["2015.12.01", "2015.12.02", "2015.12.0201"])
      expect(cached_report[:patch_fixes].keys).to eq(["2015.12.01", "2015.12.02", "2015.12.0201"])
      expect(cached_report[:hotfixes].keys).to eq(["2015.12.01", "2015.12.02", "2015.12.0201"])
      expect(cached_report[:time_in_phases].keys).to eq(["2015.12.01", "2015.12.02", "2015.12.0201"])
      expect(cached_report[:stability_contributors].keys).to eq(["2015.12.01", "2015.12.02", "2015.12.0201"])
      expect(cached_report[:contributors].keys).to eq(["2015.12.01", "2015.12.02", "2015.12.0201"])
    end
  end
end
