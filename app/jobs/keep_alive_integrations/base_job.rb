module KeepAliveIntegrations
  class BaseJob < ApplicationJob
    queue_as :default

    def perform(providable_id)
      providable = providable_class.find_by(id: providable_id)
      return unless providable

      integration = providable.integration
      return unless integration.connected? || integration.needs_reauth?

      if integration.needs_reauth?
        re_enqueue(providable_id, 3.hours)
        return
      end

      keep_alive(providable)
      re_enqueue(providable_id, 6.hours)
    rescue Installations::Error => e
      if e.reason == :token_refresh_failure
        elog(e, level: :warn)
        re_enqueue(providable_id, 3.hours)
      else
        elog(e, level: :error)
        re_enqueue(providable_id, 1.hour)
      end
    rescue => e
      elog(e, level: :error)
      re_enqueue(providable_id, 1.hour)
    end

    def re_enqueue(id, wait)
      self.class.perform_in(wait, id)
    end
  end
end
