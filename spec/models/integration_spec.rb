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
end
