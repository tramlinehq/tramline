require "rails_helper"

describe App do
  it "has a valid factory" do
    expect(create(:app, :android)).to be_valid
    expect(create(:app, :ios)).to be_valid
  end

  describe "#in_draft_mode!" do
    context "when android" do
      it "does a draft_check if draft is currently unset" do
        allow_any_instance_of(GooglePlayStoreIntegration).to receive(:draft_check?).and_return(true)
        app = create(:app, :android, draft: nil)

        result = app.in_draft_mode?

        expect(result).to be true
        expect(app.draft?).to be true
      end

      it "does not do anything if draft is currently false" do
        allow_any_instance_of(GooglePlayStoreIntegration).to receive(:draft_check?).and_return(true)
        app = create(:app, :android, draft: false)

        result = app.in_draft_mode?

        expect(result).to be false
        expect(app.draft?).to be false
      end

      it "does a draft_check if draft is currently true" do
        allow_any_instance_of(GooglePlayStoreIntegration).to receive(:draft_check?).and_return(false)
        app = create(:app, :android, draft: true)

        expect(app.draft?).to be true

        result = app.in_draft_mode?

        expect(result).to be false
        expect(app.draft?).to be false
      end
    end

    context "when ios" do
      it "does not do a draft_check if draft is currently unset" do
        app = create(:app, :ios, draft: nil)

        result = app.in_draft_mode?

        expect(result).to be false
        expect(app.draft?).to be false
      end

      it "does not do anything if draft is currently false" do
        app = create(:app, :ios, draft: false)

        result = app.in_draft_mode?

        expect(result).to be false
        expect(app.draft?).to be false
      end
    end
  end
end
