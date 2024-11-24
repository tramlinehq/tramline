class JobMiddleware::SentryContext
  module ForActiveJob
  end

  module ForSidekiq
    include Sidekiq::ServerMiddleware

    def call(worker, msg, queue)
      Sentry.configure_scope do |scope|
        scope.set_context(
          "Job Context",
          {
            "worker" => worker.class.name,
            "queue" => queue,
            "arguments" => sanitize_arguments(msg["args"])
          }
        )
      end

      yield
    end

    private

    def sanitize_arguments(args)
      args.map do |arg|
        case arg
        when Hash
          arg.transform_values { |v| sanitize_arguments([v]).first }
        when Array
          sanitize_arguments(arg)
        else
          arg.to_s
        end
      end
    end
  end
end
