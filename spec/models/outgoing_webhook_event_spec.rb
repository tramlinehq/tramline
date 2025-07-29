require "rails_helper"

describe OutgoingWebhookEvent do
  it "has a valid factory" do
    expect(create(:outgoing_webhook_event)).to be_valid
  end

  describe "validations" do
    it "requires event_timestamp" do
      event = build(:outgoing_webhook_event, event_timestamp: nil)
      expect(event).not_to be_valid
      expect(event.errors[:event_timestamp]).to include("can't be blank")
    end

    it "requires status" do
      event = build(:outgoing_webhook_event, status: nil)
      expect(event).not_to be_valid
      expect(event.errors[:status]).to include("can't be blank")
    end

    it "requires event_type" do
      event = build(:outgoing_webhook_event, event_type: nil)
      expect(event).not_to be_valid
      expect(event.errors[:event_type]).to include("can't be blank")
    end

    it "requires release" do
      event = build(:outgoing_webhook_event, release: nil)
      expect(event).not_to be_valid
      expect(event.errors[:release]).to include("must exist")
    end

    describe "event_type validation" do
      it "is valid with rc.finished event type" do
        event = build(:outgoing_webhook_event, event_type: "rc.finished")
        expect(event).to be_valid
      end

      it "is valid with release.finished event type" do
        event = build(:outgoing_webhook_event, event_type: "release.finished")
        expect(event).to be_valid
      end

      it "is valid with release.started event type" do
        event = build(:outgoing_webhook_event, event_type: "release.started")
        expect(event).to be_valid
      end

      it "is invalid with unknown event type" do
        event = build(:outgoing_webhook_event, event_type: "invalid.event")
        expect(event).not_to be_valid
        expect(event.errors[:event_type]).to include("contains invalid event type: invalid.event")
      end

      it "is invalid with empty event type" do
        event = build(:outgoing_webhook_event, event_type: "")
        expect(event).not_to be_valid
        expect(event.errors[:event_type]).to include("can't be blank")
      end
    end

    describe "status validation" do
      it "is valid with pending status" do
        event = build(:outgoing_webhook_event, status: "pending")
        expect(event).to be_valid
      end

      it "is valid with success status" do
        event = build(:outgoing_webhook_event, status: "success")
        expect(event).to be_valid
      end

      it "is valid with failed status" do
        event = build(:outgoing_webhook_event, status: "failed")
        expect(event).to be_valid
      end

      it "is invalid with unknown status" do
        expect {
          build(:outgoing_webhook_event, status: "unknown")
        }.to raise_error(ArgumentError, "'unknown' is not a valid status")
      end
    end

    describe "event_payload validation" do
      it "requires event_payload to be present at database level" do
        event = build(:outgoing_webhook_event)
        event.event_payload = nil
        expect {
          event.save!
        }.to raise_error(ActiveRecord::NotNullViolation)
      end

      it "allows valid JSON in event_payload" do
        event = build(:outgoing_webhook_event, event_payload: {platform: "android", version: "1.0.0"})
        expect(event).to be_valid
      end
    end
  end

  describe "associations" do
    let(:release) { create(:release) }
    let(:event) { create(:outgoing_webhook_event, release: release) }

    it "belongs to release" do
      expect(event.release).to eq(release)
    end

    it "requires a release to be present" do
      event = build(:outgoing_webhook_event, release: nil)
      expect(event).not_to be_valid
      expect(event.errors[:release]).to include("must exist")
    end
  end

  describe "scopes" do
    let(:release) { create(:release) }
    let!(:recent_event) { create(:outgoing_webhook_event, release:, event_timestamp: 1.hour.ago) }
    let!(:old_event) { create(:outgoing_webhook_event, release:, event_timestamp: 1.day.ago) }

    describe ".recent" do
      it "orders by event_timestamp desc" do
        expect(described_class.recent).to eq([recent_event, old_event])
      end
    end
  end

  describe "enums" do
    describe "status enum" do
      it "defines pending status" do
        event = build(:outgoing_webhook_event, status: :pending)
        expect(event.pending?).to be true
        expect(event.status).to eq("pending")
      end

      it "defines success status" do
        event = build(:outgoing_webhook_event, status: :success)
        expect(event.success?).to be true
        expect(event.status).to eq("success")
      end

      it "defines failed status" do
        event = build(:outgoing_webhook_event, status: :failed)
        expect(event.failed?).to be true
        expect(event.status).to eq("failed")
      end
    end
  end

  describe "constants" do
    describe "VALID_EVENT_TYPES" do
      it "each event type has a schema" do
        OutgoingWebhookEvent::VALID_EVENT_TYPES.each do |event_type, config|
          expect(config).to have_key(:schema)
          expect(config[:schema]).to be_a(Hash)
        end
      end
    end
  end

  describe "#record_failure!" do
    let(:event) { create(:outgoing_webhook_event, status: :pending) }

    it "updates status to failed" do
      event.record_failure!("Connection timeout")
      expect(event.reload).to be_failed
    end

    it "stores the error message" do
      error_message = "Connection timeout"
      event.record_failure!(error_message)
      expect(event.reload.error_message).to eq(error_message)
    end

    it "updates the record in the database" do
      expect {
        event.record_failure!("Network error")
      }.to change { event.reload.updated_at }
    end

    it "raises an error if save fails" do
      allow(event).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      expect {
        event.record_failure!("Error")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#record_success!" do
    let(:event) { create(:outgoing_webhook_event, status: :pending) }
    let(:response) { {id: "msg_123", status: "delivered"}.with_indifferent_access }

    it "updates status to success" do
      event.record_success!(response)
      expect(event.reload).to be_success
    end

    it "stores the response data as JSON" do
      event.record_success!(response)
      expect(event.reload.response_data).to eq(response)
    end

    it "updates the record in the database" do
      expect {
        event.record_success!(response)
      }.to change { event.reload.updated_at }
    end

    it "handles nil response" do
      event.record_success!(nil)
      expect(event.reload).to be_success
      expect(event.response_data).to be_nil
    end

    it "handles empty hash response" do
      event.record_success!({})
      expect(event.reload).to be_success
      expect(event.response_data).to eq({})
    end

    it "raises an error if save fails" do
      allow(event).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      expect {
        event.record_success!(response)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "integration tests" do
    it "creates a valid event with all required attributes" do
      release = create(:release)
      event = described_class.create!(
        release: release,
        event_type: "rc.finished",
        event_timestamp: Time.current,
        event_payload: {platform: "android", version: "1.0.0"},
        status: :pending
      )

      expect(event).to be_persisted
      expect(event.release).to eq(release)
      expect(event.event_type).to eq("rc.finished")
      expect(event).to be_pending
    end

    it "handles the complete workflow from pending to success" do
      event = create(:outgoing_webhook_event, status: :pending)
      expect(event).to be_pending

      response_data = {id: "webhook_123", delivered_at: Time.current.iso8601}.with_indifferent_access
      event.record_success!(response_data)

      event.reload
      expect(event).to be_success
      expect(event.response_data).to eq(response_data)
      expect(event.error_message).to be_nil
    end

    it "handles the complete workflow from pending to failed" do
      event = create(:outgoing_webhook_event, status: :pending)
      expect(event).to be_pending

      error_msg = "HTTP 500: Internal Server Error"
      event.record_failure!(error_msg)

      event.reload
      expect(event).to be_failed
      expect(event.error_message).to eq(error_msg)
      expect(event.response_data).to be_nil
    end
  end
end
