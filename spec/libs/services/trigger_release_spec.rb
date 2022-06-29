require "rails_helper"

describe Services::TriggerRelease do
  let(:train) { FactoryBot.create(:releases_train) }

  it ".run" do
    described_class.call(train)
  end
end
