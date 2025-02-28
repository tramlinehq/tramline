require "rails_helper"

RSpec.shared_examples "lock-acquisition retry behaviour" do
  it "retries when there's a lock acquisition error" do
    exception = GooglePlayStoreIntegration::LockAcquisitionError.new
    expect(described_class.new.sidekiq_retry_in_block.call(0, exception)).to eq(2 * 1.minute)
    expect(described_class.new.sidekiq_retry_in_block.call(1, exception)).to eq(2 * 1.minute)
    expect(described_class.new.sidekiq_retry_in_block.call(2, StandardError.new)).to eq(:kill)
  end
end
