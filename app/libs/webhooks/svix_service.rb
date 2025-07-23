module Webhooks
  class SvixService
    include Loggable

    def self.trigger_webhook(release, event_type, payload)
      new(release, event_type).trigger(payload)
    end

    def initialize(release, event_type)
      @release = release
      @train = @release.train
      @webhook = @train.webhook_integration
      @event_type = event_type
    end

    def trigger(payload)
      return if @webhook.blank? || @webhook.unavailable?
      send_webhook(build_payload(payload))
    end

    private

    attr_reader :release, :event_type

    def build_payload(payload)
      validate_payload_schema!(payload)
      {
        event_type: event_type,
        event_source: ENV["HOST_NAME"],
        event_timestamp: Time.current.iso8601,
        tramline_payload: payload
      }
    end

    def send_webhook(payload)
      event_record = create_pending_event(payload)

      begin
        response = @webhook.send_message(payload)
        event_record.record_success!(response)
      rescue SvixIntegration::WebhookApiError => error
        elog("Webhook delivery failed for #{release.id} and event_type #{event_type}: #{error.message}", level: :error)
        event_record.record_failure!(error.message)
        raise error
      end
    end

    def create_pending_event(event_payload)
      OutgoingWebhookEvent.create!(
        release:,
        event_timestamp: Time.current,
        status: :pending,
        event_type:,
        event_payload:
      )
    end

    def validate_payload_schema!(payload)
      errors = JSON::Validator.fully_validate(schema_for_event, payload)

      if errors.any?
        error_message = "Webhook payload validation failed for #{release.id} and event_type #{event_type}: #{errors.join(", ")}"
        elog(error_message, level: :error)
        raise ArgumentError, error_message
      end
    end

    def schema_for_event
      schema = OutgoingWebhookEvent::VALID_EVENT_TYPES.dig(event_type, :schema)

      unless schema
        error_message = "this event_type does not have a schema associated"
        elog(error_message, level: :error)
        raise ArgumentError, error_message
      end

      schema
    end
  end
end
