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

    it "allows up to 4000 characters in description" do
      expect(build(:release_metadata, locale:, release_platform_run:, description: "a" * 4000)).to be_valid
    end

    it "disallows more than 4000 characters in description" do
      expect(build(:release_metadata, locale:, release_platform_run:, description: "a" * 4001)).not_to be_valid
    end

    it "allows up to 100 characters in keywords" do
      expect(build(:release_metadata, locale:, release_platform_run:, keywords: ["a" * 50, "b" * 49])).to be_valid
    end

    it "disallows more than 100 characters in keywords" do
      expect(build(:release_metadata, locale:, release_platform_run:, keywords: ["a" * 50, "b" * 50])).not_to be_valid
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

    it "updates fields and clears draft for submitted fields" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "old notes",
        draft_release_notes: "draft notes")

      metadata.update_and_clear_drafts!(release_notes: "new notes")

      expect(metadata.reload.release_notes).to eq("new notes")
      expect(metadata.draft_release_notes).to be_nil
    end

    it "clears draft for any submitted field, even if value unchanged" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "same notes",
        promo_text: "old promo",
        draft_release_notes: "draft notes",
        draft_promo_text: "draft promo")

      metadata.update_and_clear_drafts!(release_notes: "same notes", promo_text: "new promo")

      expect(metadata.reload.draft_release_notes).to be_nil
      expect(metadata.draft_promo_text).to be_nil
    end

    it "does not clear draft for fields not submitted" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "notes",
        promo_text: "promo",
        draft_release_notes: "draft notes",
        draft_promo_text: "draft promo")

      metadata.update_and_clear_drafts!(release_notes: "new notes")

      expect(metadata.reload.draft_release_notes).to be_nil
      expect(metadata.draft_promo_text).to eq("draft promo")
    end

    it "raises on validation failure" do
      metadata = create(:release_metadata, locale: "en-GB", release_platform_run:, release_notes: "valid")

      expect {
        metadata.update_and_clear_drafts!(release_notes: "<invalid>")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "clears draft_keywords when keywords are submitted" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "notes",
        keywords: ["old", "words"],
        draft_keywords: ["draft", "keywords"])

      metadata.update_and_clear_drafts!(keywords: ["new", "words"])

      expect(metadata.reload.keywords).to eq(["new", "words"])
      expect(metadata.draft_keywords).to eq([])
    end

    it "clears draft_description when description is submitted" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "notes",
        description: "old desc",
        draft_description: "draft desc")

      metadata.update_and_clear_drafts!(description: "new desc")

      expect(metadata.reload.description).to eq("new desc")
      expect(metadata.draft_description).to be_nil
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

    it "compares against database values, not in-memory values" do
      metadata = create(:release_metadata, locale: "en-GB", release_platform_run:, release_notes: "original")

      # Simulate a failed update! that left dirty attributes in memory
      metadata.release_notes = "failed update value"

      # save_draft should compare against DB value ("original"), not in-memory value
      metadata.save_draft(release_notes: "draft content")

      expect(metadata.reload.draft_release_notes).to eq("draft content")
      expect(metadata.release_notes).to eq("original")
    end

    it "does not save draft when submitted value matches database value" do
      metadata = create(:release_metadata, locale: "en-GB", release_platform_run:, release_notes: "original")

      # Even with dirty in-memory state, if submitted value matches DB, no draft saved
      metadata.release_notes = "dirty value"
      metadata.save_draft(release_notes: "original")

      expect(metadata.reload.draft_release_notes).to be_nil
    end

    it "saves draft_keywords as array for changed keywords" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "notes",
        keywords: ["original", "words"])

      metadata.save_draft(keywords: ["new", "draft", "words"])

      expect(metadata.reload.draft_keywords).to eq(["new", "draft", "words"])
      expect(metadata.keywords).to eq(["original", "words"])
    end

    it "does not save draft_keywords when keywords unchanged" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "notes",
        keywords: ["same", "words"])

      metadata.save_draft(keywords: ["same", "words"])

      expect(metadata.reload.draft_keywords).to eq([])
    end

    it "saves draft_description for changed description" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "notes",
        description: "original desc")

      metadata.save_draft(description: "new draft desc")

      expect(metadata.reload.draft_description).to eq("new draft desc")
      expect(metadata.description).to eq("original desc")
    end

    it "does not save draft_description when description unchanged" do
      metadata = create(:release_metadata,
        locale: "en-GB",
        release_platform_run:,
        release_notes: "notes",
        description: "same desc")

      metadata.save_draft(description: "same desc")

      expect(metadata.reload.draft_description).to be_nil
    end
  end
end
