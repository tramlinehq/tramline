# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReleaseMetadata do
  it "has a valid factory" do
    expect(build(:release_metadata)).to be_valid
  end

  it "allows emoji characters in notes" do
    expect(build(:release_metadata, promo_text: "😀")).to be_valid
  end

  it "allows some special characters in notes" do
    expect(build(:release_metadata, promo_text: "Money money money!! ₹100 off! $$ bills yo?! (#money)")).to be_valid
  end

  it "allows accented characters in notes" do
    expect(build(:release_metadata, promo_text: "À la mode, les élèves sont bien à l'aise.")).to be_valid
  end

  it "allows non-latin characters in notes" do
    expect(build(:release_metadata, promo_text: "दिल ढूँढता है फिर वही फ़ुरसत के रात दिन, बैठे रहे तसव्वुर-ए-जानाँ किये हुए।")).to be_valid
  end

  it "allows numbers in non-latin languages in notes" do
    expect(build(:release_metadata, promo_text: "१२३४५६७८९१०१११२१३, १३ करूँ गिन गिन के")).to be_valid
  end
end
