require "rails_helper"

describe ReleaseIndexComponent do
  def create_component
    reldex = create(:release_index)
    reldex.components.sample
  end

  describe "#score" do
    let(:weight) { 0.5 }
    let(:component) { create_component }

    before do
      component.update(weight:, tolerable_range: 1..3)
    end

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
