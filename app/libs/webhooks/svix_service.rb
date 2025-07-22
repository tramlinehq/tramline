require "json"

module Webhooks
  class SvixService
    include Loggable

    def self.trigger_for_train(train, event_type, payload)
      train.outgoing_webhooks.active.for_event_type(event_type).find_each do |webhook|
        new(webhook).trigger(event_type, payload)
      end
    end

    def self.trigger_webhook(outgoing_webhook, event_type, payload)
      new(outgoing_webhook).trigger(event_type, payload)
    end

    def self.create_endpoint_for_webhook(train, url, event_types: ["release.started", "release.ended", "rc.finished"], description: nil)
      webhook_integration = train.webhook_integration

      return if webhook_integration&.app_id.blank?

      begin
        # Create the Svix endpoint first
        endpoint_response = webhook_integration.create_endpoint(url, event_types: event_types)

        # Create the OutgoingWebhook record with the endpoint ID
        train.outgoing_webhooks.create!(
          url: url,
          event_types: event_types,
          description: description,
          svix_endpoint_id: endpoint_response.respond_to?(:id) ? endpoint_response.id : nil,
          active: true
        )
      rescue HTTP::Error, Faraday::Error, StandardError => error
        # Create OutgoingWebhook with error state for tracking
        webhook = train.outgoing_webhooks.create!(
          url: url,
          event_types: event_types,
          description: description,
          active: false
        )
        # Add error to the saved webhook for inspection in tests
        webhook.errors.add(:base, "Failed to create Svix endpoint: #{error.message}")
        raise error
      end
    end

    def initialize(outgoing_webhook)
      @outgoing_webhook = outgoing_webhook
    end

    def trigger(event_type, payload)
      return unless @outgoing_webhook.active?
      return unless @outgoing_webhook.event_types.include?(event_type.to_s)

      webhook_payload = build_payload(event_type, payload)
      send_webhook(webhook_payload)
    end

    private

    attr_reader :outgoing_webhook

    def build_payload(event_type, payload)
      validate_payload_schema!(event_type, payload)
      {
        event_type: event_type,
        timestamp: Time.current.iso8601,
        data: payload,
        train: outgoing_webhook.train.webhook_params
      }
    end

    def send_webhook(payload)
      event_record = create_pending_event(payload)

      begin
        Rails.logger.info("Outgoing webhook triggered: #{outgoing_webhook.url}")
        Rails.logger.debug { "Webhook payload: #{payload.to_json}" }

        webhook_integration = outgoing_webhook.train.webhook_integration
        unless webhook_integration
          raise "No SvixIntegration found for train #{outgoing_webhook.train.id}"
        end
        unless webhook_integration.app_id
          raise "No Svix app_id found for train #{outgoing_webhook.train.id}"
        end

        response = webhook_integration.send_message(payload)

        event_record.update!(
          status: :success,
          response_data: response.to_json
        )

        Rails.logger.info("Webhook delivered successfully: #{outgoing_webhook.url}")
      rescue HTTP::Error, Faraday::Error => error
        elog("Webhook delivery failed for #{outgoing_webhook.url}: #{error.message}", level: :warn)

        event_record.update!(
          status: :failed,
          error_message: "Network error: #{error.message}"
        )

        raise error
      rescue => error
        elog("Webhook delivery failed for #{outgoing_webhook.url}: #{error.message}", level: :warn)

        event_record.update!(
          status: :failed,
          error_message: error.message
        )

        raise error
      end
    end

    def create_pending_event(payload)
      OutgoingWebhookEvent.create!(
        train: outgoing_webhook.train,
        outgoing_webhook: outgoing_webhook,
        event_timestamp: Time.current,
        status: :pending
      )
    end

    def validate_payload_schema!(event_type, payload)
      schema = schema_for_event(event_type)
      return unless schema

      errors = JSON::Validator.fully_validate(schema, payload)

      if errors.any?
        error_message = "Webhook payload validation failed for #{event_type}: #{errors.join(", ")}"
        elog(error_message, level: :error)
        raise ArgumentError, error_message
      end
    end

    def schema_for_event(event_type)
      OutgoingWebhook::VALID_EVENT_TYPES[event_type.to_s]
    end
  end
end
