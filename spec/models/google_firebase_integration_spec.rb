# frozen_string_literal: true

require "rails_helper"

describe GoogleFirebaseIntegration do
  describe "#setup_complete?" do
    let(:firebase) { create(:google_firebase_integration, :without_callbacks_and_validations) }

    context "when app is android" do
      let(:app) { create(:app, :android) }

      before do
        create(:integration,
          category: "build_channel",
          integrable: app,
          status: :connected,
          providable: firebase)
      end

      it "returns true when android_config is present" do
        firebase.update!(android_config: {app_id: "1:123:android:abc"})
        expect(firebase.setup_complete?).to be true
      end

      it "returns false when android_config is blank" do
        firebase.update!(android_config: nil)
        expect(firebase.setup_complete?).to be false
      end
    end

    context "when app is ios" do
      let(:app) { create(:app, :ios) }

      before do
        create(:integration,
          category: "build_channel",
          integrable: app,
          status: :connected,
          providable: firebase)
      end

      it "returns true when ios_config is present" do
        firebase.update!(ios_config: {app_id: "1:123:ios:abc"})
        expect(firebase.setup_complete?).to be true
      end

      it "returns false when ios_config is blank" do
        firebase.update!(ios_config: nil)
        expect(firebase.setup_complete?).to be false
      end
    end

    context "when app is cross_platform" do
      let(:app) { create(:app, :cross_platform) }

      before do
        create(:integration,
          category: "build_channel",
          integrable: app,
          status: :connected,
          providable: firebase)
      end

      it "returns true when both configs are present" do
        firebase.update!(android_config: {app_id: "1:123:android:abc"}, ios_config: {app_id: "1:123:ios:abc"})
        expect(firebase.setup_complete?).to be true
      end

      it "returns false when only android_config is present" do
        firebase.update!(android_config: {app_id: "1:123:android:abc"}, ios_config: nil)
        expect(firebase.setup_complete?).to be false
      end

      it "returns false when only ios_config is present" do
        firebase.update!(android_config: nil, ios_config: {app_id: "1:123:ios:abc"})
        expect(firebase.setup_complete?).to be false
      end
    end

    context "when integrable is an AppVariant" do
      let(:app) { create(:app, :android) }
      let(:variant) { create(:app_variant, app: app, bundle_identifier: "com.example.staging") }

      before do
        create(:integration,
          category: "build_channel",
          integrable: variant,
          status: :connected,
          providable: firebase)
      end

      it "checks config based on parent app platform" do
        firebase.update!(android_config: {app_id: "1:123:android:abc"})
        expect(firebase.setup_complete?).to be true
      end

      it "returns false when config is missing for parent app platform" do
        firebase.update!(android_config: nil)
        expect(firebase.setup_complete?).to be false
      end
    end
  end
end
