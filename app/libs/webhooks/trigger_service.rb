module Webhooks
  class TriggerService
    def self.trigger_for_train(train, event_type, payload)
      train.outgoing_webhooks.active.for_event_type(event_type).find_each do |webhook|
        SvixService.trigger_webhook(webhook, event_type, payload)
      end
    end
  end
end
