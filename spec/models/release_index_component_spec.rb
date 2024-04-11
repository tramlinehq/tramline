require "rails_helper"

describe ReleaseIndexComponent do
  it "has a valid factory" do
    expect(create(:release_index_component)).to be_valid
  end

  describe "#score" do
    let(:component) { create(:release_index_component, weight: 0.5, tolerable_range: 1..3) }

    {
      0.541 => 1,
      0.151 => 1,
      3.232 => 0,
      1.829 => 0.5,
      2.314 => 0.5,
      0.39 => 1,
      0.422 => 1,
      3.439 => 0,
      4.305 => 0,
      2.057 => 0.5
    }.each do |input, output|
      it "returns #{output} when the tolerable range input is #{input}" do
        expect(component.action_score(input)).to eq output
      end
    end
  end

  describe "#action_score?" do
    let(:weight) { 0.5 }
    let(:component) { create(:release_index_component, weight: weight, tolerable_range: 1..3) }

    {
      0.541 => 1,
      0.151 => 1,
      3.232 => 0,
      1.829 => 0.5,
      2.314 => 0.5,
      0.39 => 1,
      0.422 => 1,
      3.439 => 0,
      4.305 => 0,
      2.057 => 0.5
    }.each do |input, output|
      it "returns #{output} when the tolerable range input is #{input}" do
        output *= weight
        expect(component.score(input)).to eq output
      end
    end
  end
end
