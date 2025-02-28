module Lockable
  LockAcquisitionFailureError = Class.new(StandardError)

  def with_lock(lock_name, params, exception: nil)
    ttl = params[:ttl]
    params = params.slice(:retry_count, :retry_delay)
    Rails.application.config.distributed_lock_client.lock(lock_name, ttl, params) do |locked|
      if locked
        yield
      elsif exception
        raise exception
      else
        raise LockAcquisitionFailureError, "Could not acquire lock for #{lock_name}, try again later"
      end
    end
  end
end
