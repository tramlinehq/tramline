require "rails_helper"

describe Pagy do
  it "falls back to the last page when the requested page overflows" do
    pagy = described_class.new(count: 35, page: 99)

    expect(pagy.page).to eq(pagy.last)
  end
end
