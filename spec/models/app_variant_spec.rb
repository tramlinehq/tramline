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
end
