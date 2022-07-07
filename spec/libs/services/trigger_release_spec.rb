require "rails_helper"

RSpec.describe Services::TriggerRelease do
  let(:train) { FactoryBot.create(:releases_train) }

  it ".run" do
    described_class.call(train)
  end
end
