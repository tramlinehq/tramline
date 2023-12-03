require "rails_helper"

describe AppVariant do
  it "has a valid factory" do
    parent = "com.example"
    variant = "com.example.com"
    app = create(:app, :android, bundle_identifier: parent)
    expect(create(:app_variant, app_config: app.config, bundle_identifier: variant)).to be_valid
    expect(build(:app_variant, app_config: app.config, bundle_identifier: variant)).not_to be_valid
  end
end
