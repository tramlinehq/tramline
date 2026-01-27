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
      expect(build(:release_metadata, locale:, release_platform_run:, release_notes: "hi2u \n <3")).not_to be_valid
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

  describe "#update_and_clear_drafts!" do
    let(:release_platform) { create(:release_platform, platform: :ios) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:) }

    it "updates fields and clears draft for changed fields" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "old notes",
        draft_release_notes: "draft notes")

      metadata.update_and_clear_drafts!(release_notes: "new notes")

      expect(metadata.reload.release_notes).to eq("new notes")
      expect(metadata.draft_release_notes).to be_nil
    end

    it "does not clear draft for unchanged fields" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "same notes",
        promo_text: "old promo",
        draft_release_notes: "draft notes",
        draft_promo_text: "draft promo")

      metadata.update_and_clear_drafts!(release_notes: "same notes", promo_text: "new promo")

      expect(metadata.reload.draft_release_notes).to eq("draft notes")
      expect(metadata.draft_promo_text).to be_nil
    end

    it "raises on validation failure" do
      metadata = create(:release_metadata, locale: "en-GB", release_platform_run:, release_notes: "valid")

      expect {
        metadata.update_and_clear_drafts!(release_notes: "<invalid>")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#save_draft" do
    let(:release_platform) { create(:release_platform, platform: :ios) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:) }

    it "saves draft for changed fields" do
      metadata = create(:release_metadata, locale: "en-GB", release_platform_run:, release_notes: "original")

      metadata.save_draft(release_notes: "new content")

      expect(metadata.reload.draft_release_notes).to eq("new content")
      expect(metadata.release_notes).to eq("original")
    end

    it "does not save draft for unchanged fields" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "same",
        promo_text: "original promo")

      metadata.save_draft(release_notes: "same", promo_text: "new promo")

      expect(metadata.reload.draft_release_notes).to be_nil
      expect(metadata.draft_promo_text).to eq("new promo")
    end

    it "saves draft even with invalid content" do
      metadata = create(:release_metadata, locale: "en-GB", release_platform_run:, release_notes: "valid")

      metadata.save_draft(release_notes: "<html>invalid</html>")

      expect(metadata.reload.draft_release_notes).to eq("<html>invalid</html>")
    end
  end
end
