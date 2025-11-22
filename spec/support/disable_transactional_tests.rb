RSpec.configure do |config|
  config.around(:each, :disable_transactional_tests) do |example|
    self.use_transactional_tests = false
    example.run
  ensure
    self.use_transactional_tests = true
  end
end
