# frozen_string_literal: true

require "rails_helper"

describe Integration do
  let(:app) { create(:app, :android) }
  let(:integration) {
    create(:integration,
      category: "version_control",
      integrable: app,
      status: :connected,
      providable: create(:gitlab_integration, :without_callbacks_and_validations))
  }

  it "has a valid factory" do
    expect(create(:integration, integrable: app)).to be_valid
  end

  describe "#mark_needs_reauth!" do
    context "when integration is connected" do
      let(:integration) {
        create(:integration,
          category: "version_control",
          integrable: app,
          status: :connected,
          providable: create(:gitlab_integration, :without_callbacks_and_validations))
      }

      it "updates status to needs_reauth and returns true" do
        expect(integration.mark_needs_reauth!).to be true
        expect(integration.reload.needs_reauth?).to be true
      end

      it "uses a database transaction" do
        allow(integration).to receive(:transaction).and_call_original
        integration.mark_needs_reauth!
        expect(integration).to have_received(:transaction)
      end

      it "logs errors and returns false when update fails" do
        allow(integration).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(integration))
        allow(integration).to receive(:elog)

        expect(integration.mark_needs_reauth!).to be false
        expect(integration.reload.connected?).to be true
        expect(integration).to have_received(:elog).with(instance_of(ActiveRecord::RecordInvalid), level: :error)
      end
    end

    context "when integration is not connected" do
      let(:integration) do
        create(:integration,
          category: "version_control",
          integrable: app,
          providable: create(:gitlab_integration, :without_callbacks_and_validations)).tap do |i|
          i.update!(status: "disconnected")
        end
      end

      it "returns nil without updating" do
        expect(integration.mark_needs_reauth!).to be_nil
        expect(integration.reload.disconnected?).to be true
      end

      it "does not call update!" do
        allow(integration).to receive(:update!)
        integration.mark_needs_reauth!
        expect(integration).not_to have_received(:update!)
      end
    end

    context "when integration is already needs_reauth" do
      let(:integration) do
        create(:integration,
          category: "version_control",
          integrable: app,
          providable: create(:gitlab_integration, :without_callbacks_and_validations)).tap do |i|
          i.update!(status: "needs_reauth")
        end
      end

      it "returns nil without updating" do
        expect(integration.mark_needs_reauth!).to be_nil
        expect(integration.reload.needs_reauth?).to be true
      end
    end
  end

  describe "#disconnect" do
    context "when integration is disconnectable" do
      let(:integration) {
        create(:integration,
          category: "version_control",
          integrable: app,
          status: :connected,
          providable: create(:gitlab_integration, :without_callbacks_and_validations))
      }

      before do
        allow(integration).to receive(:disconnectable?).and_return(true)
      end

      it "updates status to disconnected and sets discarded_at" do
        freeze_time do
          expect(integration.disconnect).to be true
          integration.reload
          expect(integration.disconnected?).to be true
          expect(integration.discarded_at).to eq(Time.current)
        end
      end

      it "uses a database transaction" do
        allow(integration).to receive(:transaction).and_call_original
        integration.disconnect
        expect(integration).to have_received(:transaction)
      end

      it "returns false and adds errors when update fails" do
        allow(integration).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(integration))

        expect(integration.disconnect).to be false
        expect(integration.errors[:base]).to be_present
        expect(integration.reload.connected?).to be true
      end
    end

    context "when integration is not disconnectable" do
      let(:integration) {
        create(:integration,
          category: "version_control",
          integrable: app,
          status: :connected,
          providable: create(:gitlab_integration, :without_callbacks_and_validations))
      }

      before do
        allow(integration).to receive(:disconnectable?).and_return(false)
      end

      it "returns nil without updating" do
        expect(integration.disconnect).to be_nil
        expect(integration.reload.connected?).to be true
      end
    end
  end

  describe "status transitions" do
    let(:integration) {
      create(:integration,
        category: "version_control",
        integrable: app,
        providable: create(:gitlab_integration, :without_callbacks_and_validations))
    }

    it "allows transition from connected to needs_reauth" do
      integration.update!(status: :connected)
      integration.mark_needs_reauth!
      expect(integration.needs_reauth?).to be true
    end

    it "allows transition from needs_reauth back to connected" do
      integration.update!(status: :needs_reauth)
      integration.update!(status: :connected)
      expect(integration.connected?).to be true
    end

    it "allows transition from connected to disconnected" do
      integration.update!(status: :connected)
      allow(integration).to receive(:disconnectable?).and_return(true)
      integration.disconnect
      expect(integration.disconnected?).to be true
    end
  end

  describe "scopes with needs_reauth status" do
    let(:connected_integration) {
      create(:integration,
        category: "version_control",
        integrable: app,
        status: :connected,
        providable: create(:gitlab_integration, :without_callbacks_and_validations))
    }
    let(:needs_reauth_integration) do
      create(:integration,
        category: "ci_cd",
        integrable: app,
        providable: create(:gitlab_integration, :without_callbacks_and_validations)).tap do |i|
        i.update!(status: "needs_reauth")
      end
    end

    let(:disconnected_integration) do
      create(:integration, integrable: app).tap do |i|
        i.update!(status: "disconnected")
      end
    end

    describe ".linked" do
      it "includes connected and needs_reauth integrations" do
        linked = described_class.linked
        expect(linked).to include(connected_integration, needs_reauth_integration)
        expect(linked).not_to include(disconnected_integration)
      end
    end

    describe ".ready" do
      it "includes only connected integrations" do
        ready = described_class.ready
        expect(ready).to include(connected_integration)
        expect(ready).not_to include(needs_reauth_integration, disconnected_integration)
      end
    end
  end

  describe "#disconnectable?" do
    context "when integrable is an App with no active runs" do
      it "returns true" do
        allow(app).to receive(:active_runs).and_return(Release.none)
        expect(integration.disconnectable?).to be true
      end
    end

    context "when integrable is an App with active runs" do
      it "returns false" do
        active_runs = instance_double(ActiveRecord::Relation, none?: false)
        allow(app).to receive(:active_runs).and_return(active_runs)
        expect(integration.disconnectable?).to be false
      end
    end

    context "when integrable is an AppVariant" do
      let(:variant) { create(:app_variant, app: app, bundle_identifier: "com.example.staging") }
      let(:variant_integration) {
        create(:integration,
          category: "build_channel",
          integrable: variant,
          status: :connected,
          providable: create(:google_firebase_integration, :without_callbacks_and_validations))
      }

      it "delegates to the variant which delegates to the app" do
        allow(app).to receive(:active_runs).and_return(Release.none)
        expect(variant_integration.disconnectable?).to be true
      end
    end
  end

  describe "#setup_complete?" do
    context "when further_setup? is false" do
      it "returns true" do
        allow(integration).to receive(:further_setup?).and_return(false)
        expect(integration.setup_complete?).to be true
      end
    end

    context "when further_setup? is true and providable responds to setup_complete?" do
      it "delegates to providable" do
        allow(integration).to receive(:further_setup?).and_return(true)
        allow(integration.providable).to receive(:setup_complete?).and_return(false)
        expect(integration.setup_complete?).to be false
      end
    end

    context "when further_setup? is true and providable does not respond to setup_complete?" do
      it "returns false" do
        providable = instance_double(SlackIntegration)
        allow(integration).to receive_messages(further_setup?: true, providable: providable)
        expect(integration.setup_complete?).to be false
      end
    end
  end

  describe "#requires_configuration?" do
    context "when further_setup? is true and setup_complete? is false" do
      it "returns true" do
        allow(integration).to receive_messages(further_setup?: true, setup_complete?: false)
        expect(integration.requires_configuration?).to be true
      end
    end

    context "when further_setup? is true and setup_complete? is true" do
      it "returns false" do
        allow(integration).to receive_messages(further_setup?: true, setup_complete?: true)
        expect(integration.requires_configuration?).to be false
      end
    end

    context "when further_setup? is false" do
      it "returns false" do
        allow(integration).to receive(:further_setup?).and_return(false)
        expect(integration.requires_configuration?).to be false
      end
    end
  end

  describe ".further_setup_by_category" do
    let(:firebase_integration) {
      create(:integration,
        category: "build_channel",
        integrable: app,
        status: :connected,
        providable: create(:google_firebase_integration, :without_callbacks_and_validations))
    }

    it "returns categories with further_setup and ready status" do
      firebase_integration
      result = app.integrations.further_setup_by_category
      expect(result).to have_key("build_channel")
      expect(result["build_channel"][:further_setup]).to be true
    end

    it "marks category as ready when all integrations have setup complete" do
      firebase_integration
      allow_any_instance_of(GoogleFirebaseIntegration).to receive(:setup_complete?).and_return(true)
      result = app.integrations.further_setup_by_category
      expect(result["build_channel"][:ready]).to be true
    end

    it "marks category as not ready when setup is incomplete" do
      firebase_integration
      allow_any_instance_of(GoogleFirebaseIntegration).to receive(:setup_complete?).and_return(false)
      result = app.integrations.further_setup_by_category
      expect(result["build_channel"][:ready]).to be false
    end

    it "skips notification category" do
      create(:integration,
        :notification,
        integrable: app,
        status: :connected)
      result = app.integrations.further_setup_by_category
      expect(result).not_to have_key("notification")
    end
  end

  describe "app_variant_restriction validation" do
    it "rejects non-build_channel category for app variants" do
      variant = create(:app_variant, app: app, bundle_identifier: "com.example.staging")
      integration = build(:integration,
        category: "version_control",
        integrable: variant,
        providable: build(:google_firebase_integration, :without_callbacks_and_validations))
      expect(integration).not_to be_valid
      expect(integration.errors[:category]).to be_present
    end

    context "when android app" do
      let(:variant) { create(:app_variant, app: app, bundle_identifier: "com.example.staging") }

      it "allows GoogleFirebaseIntegration" do
        integration = build(:integration,
          category: "build_channel",
          integrable: variant,
          providable: build(:google_firebase_integration, :without_callbacks_and_validations))
        expect(integration).to be_valid
      end

      it "allows GooglePlayStoreIntegration" do
        integration = build(:integration,
          category: "build_channel",
          integrable: variant,
          providable: build(:google_firebase_integration, :without_callbacks_and_validations))
        integration.providable_type = "GooglePlayStoreIntegration"
        expect(integration).to be_valid
      end

      it "rejects AppStoreIntegration" do
        integration = build(:integration,
          category: "build_channel",
          integrable: variant,
          providable: build(:google_firebase_integration, :without_callbacks_and_validations))
        integration.providable_type = "AppStoreIntegration"
        expect(integration).not_to be_valid
        expect(integration.errors[:providable_type]).to be_present
      end
    end

    context "when ios app" do
      let(:ios_app) { create(:app, :ios) }
      let(:variant) { create(:app_variant, app: ios_app, bundle_identifier: "com.example.staging") }

      it "allows GoogleFirebaseIntegration" do
        integration = build(:integration,
          category: "build_channel",
          integrable: variant,
          providable: build(:google_firebase_integration, :without_callbacks_and_validations))
        expect(integration).to be_valid
      end

      it "allows AppStoreIntegration" do
        integration = build(:integration,
          category: "build_channel",
          integrable: variant,
          providable: build(:google_firebase_integration, :without_callbacks_and_validations))
        integration.providable_type = "AppStoreIntegration"
        expect(integration).to be_valid
      end

      it "rejects GooglePlayStoreIntegration" do
        integration = build(:integration,
          category: "build_channel",
          integrable: variant,
          providable: build(:google_firebase_integration, :without_callbacks_and_validations))
        integration.providable_type = "GooglePlayStoreIntegration"
        expect(integration).not_to be_valid
        expect(integration.errors[:providable_type]).to be_present
      end
    end

    context "when cross_platform app" do
      let(:cp_app) { create(:app, :cross_platform) }
      let(:variant) { create(:app_variant, app: cp_app, bundle_identifier: "com.example.staging") }

      it "allows GoogleFirebaseIntegration" do
        integration = build(:integration,
          category: "build_channel",
          integrable: variant,
          providable: build(:google_firebase_integration, :without_callbacks_and_validations))
        expect(integration).to be_valid
      end

      it "allows GooglePlayStoreIntegration" do
        integration = build(:integration,
          category: "build_channel",
          integrable: variant,
          providable: build(:google_firebase_integration, :without_callbacks_and_validations))
        integration.providable_type = "GooglePlayStoreIntegration"
        expect(integration).to be_valid
      end

      it "allows AppStoreIntegration" do
        integration = build(:integration,
          category: "build_channel",
          integrable: variant,
          providable: build(:google_firebase_integration, :without_callbacks_and_validations))
        integration.providable_type = "AppStoreIntegration"
        expect(integration).to be_valid
      end

      it "rejects SlackIntegration" do
        integration = build(:integration,
          category: "build_channel",
          integrable: variant,
          providable: build(:google_firebase_integration, :without_callbacks_and_validations))
        integration.providable_type = "SlackIntegration"
        expect(integration).not_to be_valid
        expect(integration.errors[:providable_type]).to be_present
      end
    end
  end

  describe ".by_categories_for" do
    let(:organization) { create(:organization) }
    let(:app) { create(:app, :android, organization: organization) }

    context "when sentry_integration flag is disabled" do
      before do
        Flipper.disable(:sentry_integration, organization)
      end

      it "excludes SentryIntegration from monitoring integrations" do
        integrations = described_class.by_categories_for(app)
        monitoring_providers = integrations["monitoring"].map(&:providable_type)

        expect(monitoring_providers).not_to include("SentryIntegration")
        expect(monitoring_providers).to include("BugsnagIntegration", "CrashlyticsIntegration")
      end
    end

    context "when sentry_integration flag is enabled" do
      before do
        Flipper.enable(:sentry_integration, organization)
      end

      it "includes SentryIntegration in monitoring integrations" do
        integrations = described_class.by_categories_for(app)
        monitoring_providers = integrations["monitoring"].map(&:providable_type)

        expect(monitoring_providers).to include("SentryIntegration")
        expect(monitoring_providers).to include("BugsnagIntegration", "CrashlyticsIntegration")
      end
    end
  end
end
