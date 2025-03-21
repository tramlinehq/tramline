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

  def parse_fixture(path, transformations)
    File.read("spec/fixtures/#{path}")
        .then { |pr| JSON.parse(pr) }
        .then { |parsed_pr| Installations::Response::Keys.transform([parsed_pr], transformations) }
        .first
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end
