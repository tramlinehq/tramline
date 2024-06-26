# frozen_string_literal: true

require "rails_helper"

describe AppStoreRollout do
  it "has a valid factory" do
    expect(create(:app_store_rollout)).to be_valid
  end

end
