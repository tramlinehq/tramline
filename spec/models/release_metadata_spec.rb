# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReleaseMetadata do
  let(:locale) { "en-GB" }

  it "has a valid factory" do
    expect(build(:release_metadata)).to be_valid
  end

  context "when iOS" do
    let(:release_platform) { create(:release_platform, platform: :ios) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:) }

    it "disallow emoji characters in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "➡️ something\n😀 💃🏽")).not_to be_valid
    end

    it "allows currencies in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "Money money money!! ₹100 off! => $$ bills yo?! (#money)")).to be_valid
    end

    it "allows accented characters in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "À la mode, les élèves sont bien à l'aise.")).to be_valid
    end

    it "allows non-latin characters in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "दिल ढूँढता है फिर वही फ़ुरसत के रात दिन, बैठे रहे तसव्वुर-ए-जानाँ किये हुए।")).to be_valid
    end

    it "allows numbers in non-latin languages in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "१२३४५६७८९१०१११२१३, १३ करूँ गिन गिन के")).to be_valid
    end

    it "allows up to 4000 characters in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "a" * 4000)).to be_valid
    end

    it "disallows more than 4000 characters in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "a" * 4001)).not_to be_valid
    end

    it "disallows '<' in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "<a>")).not_to be_valid
    end
  end

  context "when android" do
    let(:release_platform) { create(:release_platform, platform: :android) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:) }

    it "allows emoji characters in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "➡️ something\n😀 💃🏽")).to be_valid
    end

    it "allows currencies in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "Money money money!! ₹100 off! => $$ bills yo?! (#money)")).to be_valid
    end

    it "allows accented characters in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "À la mode, les élèves sont bien à l'aise.")).to be_valid
    end

    it "allows non-latin characters in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "दिल ढूँढता है फिर वही फ़ुरसत के रात दिन, बैठे रहे तसव्वुर-ए-जानाँ किये हुए।")).to be_valid
    end

    it "allows numbers in non-latin languages in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "१२३४५६७८९१०१११२१३, १३ करूँ गिन गिन के")).to be_valid
    end

    it "allows up to 500 characters in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "a" * 500)).to be_valid
    end

    it "disallows more than 500 characters in notes" do
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "a" * 501)).not_to be_valid
    end
  end
end
