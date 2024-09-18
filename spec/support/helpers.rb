module TestHelpers
  def raise_times(instance, exception, method, max_exceptions = 1)
    exception_raised_count = 0

    allow_any_instance_of(instance).to receive(method) do
      if exception_raised_count < max_exceptions
        exception_raised_count += 1
        raise exception
      end
    end
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end
