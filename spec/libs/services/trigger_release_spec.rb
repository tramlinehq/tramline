require "rails_helper"

RSpec.describe Triggers::Release do
  let(:train) { create(:releases_train) }

  it ".run" do
    described_class.call(train)
  end
end
