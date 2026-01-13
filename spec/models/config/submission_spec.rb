require "rails_helper"

describe Config::Submission do
  let(:app) { create(:app, :android) }
  let(:release_platform) { create(:release_platform, app:, platform: "android") }
  let(:platform_config) { release_platform.platform_config }
  let(:production_release_config) { platform_config.production_release }
  let(:submission) { production_release_config.submissions.first }

  describe "#parsed_production_form_factor" do
    context "when identifier has no form factor prefix" do
      before do
        submission.submission_external.identifier = "production"
      end

      it "returns nil" do
        expect(submission.parsed_production_form_factor).to be_nil
      end
    end

    context "when identifier has a valid form factor prefix" do
      it "returns 'wear' for wear:production" do
        submission.submission_external.identifier = "wear:production"
        expect(submission.parsed_production_form_factor).to eq("wear")
      end

      it "returns 'tv' for tv:production" do
        submission.submission_external.identifier = "tv:production"
        expect(submission.parsed_production_form_factor).to eq("tv")
      end

      it "returns 'automotive' for automotive:production" do
        submission.submission_external.identifier = "automotive:production"
        expect(submission.parsed_production_form_factor).to eq("automotive")
      end
    end

    context "when identifier has an invalid prefix" do
      before do
        submission.submission_external.identifier = "invalid:production"
      end

      it "returns nil" do
        expect(submission.parsed_production_form_factor).to be_nil
      end
    end

    context "when submission_external is nil" do
      before do
        allow(submission).to receive(:submission_external).and_return(nil)
      end

      it "returns nil" do
        expect(submission.parsed_production_form_factor).to be_nil
      end
    end
  end

  describe "#production_form_factor" do
    context "when setting form factor on an existing submission" do
      before do
        submission.submission_external.identifier = "production"
      end

      it "updates identifier with form factor prefix on save" do
        submission.production_form_factor = "wear"
        submission.save!

        expect(submission.submission_external.identifier).to eq("wear:production")
      end

      it "handles changing from one form factor to another" do
        submission.submission_external.identifier = "wear:production"
        submission.production_form_factor = "tv"
        submission.save!

        expect(submission.submission_external.identifier).to eq("tv:production")
      end

      it "removes form factor prefix when set to blank" do
        submission.submission_external.identifier = "wear:production"
        submission.production_form_factor = ""
        submission.save!

        expect(submission.submission_external.identifier).to eq("production")
      end
    end

    context "when form factor is not changed" do
      it "does not modify the identifier" do
        submission.submission_external.identifier = "production"
        original_identifier = submission.submission_external.identifier

        # Save without setting production_form_factor
        submission.rollout_enabled = true
        submission.rollout_stages = [1, 5, 10, 50, 100]
        submission.save!

        expect(submission.submission_external.identifier).to eq(original_identifier)
      end
    end
  end

  describe "form factor with different base tracks" do
    before do
      submission.submission_external.identifier = "beta"
    end

    it "applies form factor to non-production tracks" do
      submission.production_form_factor = "wear"
      submission.save!

      expect(submission.submission_external.identifier).to eq("wear:beta")
    end
  end

  describe "base_production_identifier extraction" do
    it "extracts 'production' from 'wear:production'" do
      submission.submission_external.identifier = "wear:production"
      submission.production_form_factor = "tv"
      submission.save!

      expect(submission.submission_external.identifier).to eq("tv:production")
    end

    it "extracts 'beta' from 'automotive:beta'" do
      submission.submission_external.identifier = "automotive:beta"
      submission.production_form_factor = "wear"
      submission.save!

      expect(submission.submission_external.identifier).to eq("wear:beta")
    end

    it "preserves identifier when no form factor prefix exists" do
      submission.submission_external.identifier = "alpha"
      submission.production_form_factor = "tv"
      submission.save!

      expect(submission.submission_external.identifier).to eq("tv:alpha")
    end
  end
end
