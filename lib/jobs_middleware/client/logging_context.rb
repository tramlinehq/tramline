module JobsMiddleware
  module Client
    class LoggingContext
      def call(_worker, job, _queue, _redis_pool)
        context = {
          user_id: Current.user&.id,
          user_name: Current.user&.full_name,
          user_email: Current.user&.email,
          organization_id: Current.organization&.slug,
          app_id: Current.app_id
        }.compact

        job["context"] = context unless context.empty?

        yield
      end
    end
  end
end
