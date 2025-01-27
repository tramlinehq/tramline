module JobsMiddleware
  module Server
    class LoggingContext
      def call(worker, job, queue)
        Sentry.configure_scope do |scope|
          scope.set_context(
            "Job",
            {
              "job" => worker.class.name,
              "queue" => queue,
              "arguments" => sanitize_arguments(job["args"])
            }
          )
          if job["context"].present?
            scope.set_context(
              "Domain",
              job["context"]
            )
          end
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
end
