require "rails_helper"

describe Config::ReleasePlatform do
  let(:app) { create(:app, :ios) }
  let(:base_config) {
    {
      workflows: {
        internal: nil,
        release_candidate: {
          name: Faker::FunnyName.name,
          id: Faker::Number.number(digits: 8),
          artifact_name_pattern: nil
        }
      },
      internal_release: nil,
      beta_release: nil,
      production_release: {
        auto_promote: false,
        submissions: [
          {number: 1,
           integrable_id: app.id,
           integrable_type: "App",
           submission_type: "AppStoreSubmission",
           submission_config: AppStoreIntegration::PROD_CHANNEL,
           rollout_config: {enabled: true, stages: AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE},
           auto_promote: false}
        ]
      }
    }
  }

  describe "validations" do
    it "validates presence of release_candidate" do
      release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
      release_platform.release_candidate_workflow = nil
      expect(release_platform).not_to be_valid
      expect(release_platform.errors.messages[:release_candidate_workflow]).to include("the release candidate workflow must be configured")
    end

    it "validates presence of beta_release" do
      release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
      release_platform.beta_release = nil
      expect(release_platform).not_to be_valid
      expect(release_platform.errors.messages[:beta_release]).to include("the beta release must be configured")
    end

    describe "duplication of internal release and release candidate workflow" do
      before do
        base_config[:workflows][:internal] = base_config[:workflows][:release_candidate].deep_dup
        base_config[:internal_release] = base_config[:production_release]
        base_config[:beta_release] = {
          submissions: [
            {number: 1,
             integrable_id: app.id,
             integrable_type: "App",
             submission_type: "GooglePlayStoreSubmission",
             submission_config: {id: "beta", name: "Open testing"},
             rollout_config: {enabled: false},
             auto_promote: false}
          ]
        }
      end

      it "is not valid" do
        release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
        expect(release_platform).not_to be_valid
      end

      context "when parameters are defined only in release_candidate" do
        before do
          base_config[:workflows][:release_candidate][:parameters] = [{name: "p1", value: "v1"}, {name: "p2", value: "v2"}]
        end

        it "is valid" do
          release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
          expect(release_platform).to be_valid
        end
      end

      context "when parameters are defined only in internal" do
        before do
          base_config[:workflows][:internal][:parameters] = [{name: "p1", value: "v1"}, {name: "p2", value: "v2"}]
        end

        it "is valid" do
          release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
          expect(release_platform).to be_valid
        end
      end

      context "when parameters are defined in both and are having same values" do
        before do
          base_config[:workflows][:internal][:parameters] = [{name: "p1", value: "v1"}, {name: "p2", value: "v2"}]
          base_config[:workflows][:release_candidate][:parameters] = [{name: "p1", value: "v1"}, {name: "p2", value: "v2"}]
        end

        it "is not valid" do
          release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
          expect(release_platform).not_to be_valid
        end
      end

      context "when parameters are defined in both and are having same values and workflow identifiers are different" do
        before do
          base_config[:workflows][:internal][:id] = Faker::Number.number(digits: 8)
          base_config[:workflows][:internal][:parameters] = [{name: "p1", value: "v1"}, {name: "p2", value: "v2"}]
          base_config[:workflows][:release_candidate][:parameters] = [{name: "p1", value: "v1"}, {name: "p2", value: "v2"}]
        end

        it "is valid" do
          release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
          expect(release_platform).to be_valid
        end
      end

      context "when parameters are defined in both and are having different values" do
        before do
          base_config[:workflows][:internal][:parameters] = [{name: "p1", value: "v1"}, {name: "p2", value: "v2"}]
          base_config[:workflows][:release_candidate][:parameters] = [{name: "rp1", value: "v1"}, {name: "rp2", value: "v2"}]
        end

        it "is valid" do
          release_platform = described_class.from_json(base_config.merge(release_platform: create(:release_platform)))
          expect(release_platform).to be_valid
        end
      end
    end

    describe "submission uniqueness across release steps" do
      let(:app) { create(:app, :android) }
      let(:release_platform) { create(:release_platform, app:, platform: "android") }
      let(:shared_channel) { {id: "internal", name: "Internal testing", is_internal: true} }

      before do
        base_config[:workflows][:internal] = {
          name: "Internal Workflow",
          id: Faker::Number.number(digits: 8),
          artifact_name_pattern: nil
        }
        base_config[:internal_release] = {
          submissions: [
            {
              number: 1,
              integrable_id: app.id,
              integrable_type: "App",
              submission_type: "PlayStoreSubmission",
              submission_config: shared_channel,
              rollout_config: {enabled: false},
              auto_promote: false
            }
          ]
        }
        base_config[:beta_release] = {
          submissions: [
            {
              number: 1,
              integrable_id: app.id,
              integrable_type: "App",
              submission_type: "PlayStoreSubmission",
              submission_config: shared_channel,
              rollout_config: {enabled: false},
              auto_promote: false
            }
          ]
        }
        base_config[:production_release] = nil
      end

      it "is not valid when internal and beta use the same channel" do
        config = described_class.from_json(base_config.merge(release_platform:))
        expect(config).not_to be_valid
        expect(config.errors[:base]).to include("a build can not be submitted to the same channel more than once")
      end

      it "is valid when internal and beta use different channels" do
        base_config[:beta_release][:submissions].first[:submission_config] = {id: "alpha", name: "Alpha testing", is_internal: false}
        config = described_class.from_json(base_config.merge(release_platform:))
        expect(config).to be_valid
      end
    end
  end

  describe "#allowed_pre_prod_submissions" do
    let(:app) { create(:app, :android) }
    let(:release_platform) { create(:release_platform, app:, platform: "android") }
    let(:platform_config) { described_class.from_json(base_config.merge(release_platform:)) }

    context "when app has configured integrations" do
      it "includes submissions for connected and configured integrations" do
        firebase = app.integrations.connected.build_channel
          .find { |i| i.providable_type == "GoogleFirebaseIntegration" }

        if firebase
          allow(firebase).to receive(:setup_complete?).and_return(true)
          allow(firebase.providable).to receive(:build_channels).and_return([{id: "group1", name: "Testers"}])
        end

        result = platform_config.allowed_pre_prod_submissions
        default_variant = result[:variants].find { |v| v[:type] == "App" }
        expect(default_variant).to be_present
        expect(default_variant[:id]).to eq(app.id)
      end
    end

    context "when app has unconfigured integrations" do
      it "excludes integrations that are not setup_complete" do
        allow_any_instance_of(Integration).to receive(:setup_complete?).and_return(false)

        result = platform_config.allowed_pre_prod_submissions
        default_variant = result[:variants].find { |v| v[:type] == "App" }
        expect(default_variant[:submissions]).to be_empty
      end
    end

    context "when app has variants" do
      let!(:variant) { create(:app_variant, app: app, bundle_identifier: "com.example.staging") }

      it "includes variants in the result" do
        result = platform_config.allowed_pre_prod_submissions
        variant_entry = result[:variants].find { |v| v[:type] == "AppVariant" }
        expect(variant_entry).to be_present
        expect(variant_entry[:id]).to eq(variant.id)
      end

      it "excludes unconfigured variant integrations" do
        firebase = create(:google_firebase_integration, :without_callbacks_and_validations)
        create(:integration,
          category: "build_channel",
          integrable: variant,
          status: :connected,
          providable: firebase)
        # Firebase without config is not setup_complete
        firebase.update!(android_config: nil)

        result = platform_config.allowed_pre_prod_submissions
        variant_entry = result[:variants].find { |v| v[:type] == "AppVariant" }
        expect(variant_entry[:submissions]).to be_empty
      end

      it "includes configured variant integrations" do
        firebase = create(:google_firebase_integration, :without_callbacks_and_validations)
        create(:integration,
          category: "build_channel",
          integrable: variant,
          status: :connected,
          providable: firebase)
        firebase.update!(android_config: {app_id: "1:123:android:abc"})
        allow_any_instance_of(GoogleFirebaseIntegration).to receive(:build_channels)
          .and_return([{id: "group1", name: "Testers"}])

        result = platform_config.allowed_pre_prod_submissions
        variant_entry = result[:variants].find { |v| v[:type] == "AppVariant" }
        expect(variant_entry[:submissions]).not_to be_empty
      end

      it "excludes disconnected variant integrations" do
        firebase = create(:google_firebase_integration, :without_callbacks_and_validations)
        integration = create(:integration,
          category: "build_channel",
          integrable: variant,
          status: :connected,
          providable: firebase)
        firebase.update!(android_config: {app_id: "1:123:android:abc"})
        allow(integration).to receive(:disconnectable?).and_return(true)
        integration.disconnect

        result = platform_config.allowed_pre_prod_submissions
        variant_entry = result[:variants].find { |v| v[:type] == "AppVariant" }
        expect(variant_entry[:submissions]).to be_empty
      end
    end
  end

  describe "#has_restricted_public_channels?" do
    it "returns false for an ios config" do
      config = described_class.from_json(base_config.merge(release_platform: create(:release_platform, platform: "ios")))
      expect(config.has_restricted_public_channels?).to be(false)
    end

    context "when android" do
      let(:app) { create(:app, :android) }
      let(:release_platform) { create(:release_platform, app:, platform: "android") }
      let(:base_config) {
        {
          workflows: {
            internal: nil,
            release_candidate: {
              name: Faker::FunnyName.name,
              id: Faker::Number.number(digits: 8),
              artifact_name_pattern: nil
            }
          },
          internal_release: nil,
          beta_release: nil,
          production_release: {
            auto_promote: false,
            submissions: [
              {number: 1,
               integrable_id: app.id,
               integrable_type: "App",
               submission_type: "PlayStoreSubmission",
               submission_config: GooglePlayStoreIntegration::PROD_CHANNEL,
               rollout_config: {enabled: true, stages: [1, 5, 10, 50, 100]},
               auto_promote: false}
            ]
          }
        }
      }

      it "returns true when production release is enabled" do
        config = described_class.from_json(base_config.merge(release_platform:))
        expect(config.has_restricted_public_channels?).to be(true)
      end

      it "returns true when there are public tracks in internal release" do
        base_config[:internal_release] = {
          submissions: [
            {number: 1,
             submission_type: "GooglePlayStoreSubmission",
             submission_config: {id: "alpha", name: "Closed testing - Alpha"},
             rollout_config: {enabled: false},
             auto_promote: false}
          ]
        }
        base_config[:production_release] = nil
        config = described_class.from_json(base_config.merge(release_platform:))
        expect(config.has_restricted_public_channels?).to be(true)
      end

      it "returns true when there are public tracks in beta release" do
        base_config[:beta_release] = {
          submissions: [
            {number: 1,
             submission_type: "GooglePlayStoreSubmission",
             submission_config: {id: "beta", name: "Open testing"},
             rollout_config: {enabled: false},
             auto_promote: false}
          ]
        }
        base_config[:production_release] = nil
        config = described_class.from_json(base_config.merge(release_platform:))
        expect(config.has_restricted_public_channels?).to be(true)
      end

      it "returns false when there no public tracks in any release" do
        base_config[:internal_release] = {
          submissions: [
            {number: 1,
             submission_type: "GoogleFirebaseSubmission",
             submission_config: {id: "testing-group-1", name: "Testing Group 1"},
             rollout_config: {enabled: false},
             auto_promote: false}
          ]
        }
        base_config[:beta_release] = {
          submissions: [
            {number: 1,
             submission_type: "GooglePlayStoreSubmission",
             submission_config: {id: "internal", name: "Internal testing"},
             rollout_config: {enabled: false},
             auto_promote: false}
          ]
        }
        base_config[:production_release] = nil
        config = described_class.from_json(base_config.merge(release_platform:))
        expect(config.has_restricted_public_channels?).to be(false)
      end
    end
  end
end
