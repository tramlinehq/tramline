# frozen_string_literal: true

require "rails_helper"

describe StoreSubmissions::PlayStore::UpdateExternalReleaseJob do
  it_behaves_like "lock-acquisition retry behaviour"
end
