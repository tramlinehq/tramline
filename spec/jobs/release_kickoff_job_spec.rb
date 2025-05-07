# frozen_string_literal: true

require "rails_helper"

describe ReleaseKickoffJob do
  let(:train) { create(:train, :active) }
  let(:release) { create(:release, train:) }

  it "kicks off the release" do
    allow(Coordinators::Actions).to receive(:start_release!).and_return(GitHub::Result.new)
    scheduled_release = create(:scheduled_release, train:, release:)

    described_class.new.perform(scheduled_release.id)

    expect(Coordinators::Actions).to have_received(:start_release!).with(scheduled_release.train, automatic: true)
  end

  it "skips starting the release if it was manually skipped" do
    allow(Coordinators::Actions).to receive(:start_release!).and_return(GitHub::Result.new)
    scheduled_release = create(:scheduled_release, train: release.train, release:, manually_skipped: true)

    described_class.new.perform(scheduled_release.id)

    expect(Coordinators::Actions).not_to have_received(:start_release!)
  end
end
