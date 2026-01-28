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

  it "writes to the train devops report query cache" do
    allow(Queries::ReleaseBreakdown).to receive(:warm)
    allow(Queries::DevopsReport).to receive(:warm).and_call_original

    expect do
      described_class.new.perform(release.id)
    end.to change {
      Rails.cache.exist?("train/#{train.id}/queries/devops_report")
    }.from(false).to(true)
  end
end
