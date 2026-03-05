require "rails_helper"

describe AppVariant do
  it "has a valid factory" do
    parent = "com.example"
    variant = "com.example.com"
    app = create(:app, :android, bundle_identifier: parent)
    expect(create(:app_variant, app: app, bundle_identifier: variant)).to be_valid
  end

  it "allows multiple variants per app" do
    app = create(:app, :android, bundle_identifier: "com.example")
    create(:app_variant, app: app, bundle_identifier: "com.example.staging")
    expect(build(:app_variant, app: app, bundle_identifier: "com.example.beta")).to be_valid
  end

  it "does not allow duplicate bundle identifiers within the same app" do
    app = create(:app, :android, bundle_identifier: "com.example")
    create(:app_variant, app: app, bundle_identifier: "com.example.staging")
    expect(build(:app_variant, app: app, bundle_identifier: "com.example.staging")).not_to be_valid
  end

  it "does not allow bundle identifier same as parent app" do
    app = create(:app, :android, bundle_identifier: "com.example")
    expect(build(:app_variant, app: app, bundle_identifier: "com.example")).not_to be_valid
  end

  describe "delegations" do
    let(:app) { create(:app, :android, bundle_identifier: "com.example") }
    let(:variant) { create(:app_variant, app: app, bundle_identifier: "com.example.staging") }

    it "delegates active_runs to app" do
      expect(variant.active_runs).to eq(app.active_runs)
    end

    it "delegates platform to app" do
      expect(variant.platform).to eq(app.platform)
    end

    it "delegates organization to app" do
      expect(variant.organization).to eq(app.organization)
    end
  end

  describe "integrations" do
    let(:app) { create(:app, :android, bundle_identifier: "com.example") }
    let(:variant) { create(:app_variant, app: app, bundle_identifier: "com.example.staging") }

    it "can have build_channel integrations" do
      firebase = create(:google_firebase_integration, :without_callbacks_and_validations)
      integration = create(:integration,
        category: "build_channel",
        integrable: variant,
        status: :connected,
        providable: firebase)
      expect(variant.integrations).to include(integration)
    end
  end
end
