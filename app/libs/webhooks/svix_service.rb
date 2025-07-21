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

        svix_client = Svix::Client.new(ENV["SVIX_TOKEN"])
        response = svix_client.message.create(
          app_id: outgoing_webhook.train.app_id,
          message: {
            eventType: payload[:event_type],
            payload: payload
          }
        )

        event_record.update!(
          status: :success,
          response_data: response.to_json
        )

        Rails.logger.info("Webhook delivered successfully: #{outgoing_webhook.url}")
      rescue => error
        Rails.logger.error("Webhook delivery failed: #{error.message}")

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
  end
end
