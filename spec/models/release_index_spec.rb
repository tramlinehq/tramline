require "rails_helper"

describe ReleaseIndex do
  it "has a valid factory" do
    expect(create(:release_index)).to be_valid
  end

  describe "validations" do
    it "is invalid for a tolerance range less than 0" do
      index = build(:release_index, tolerable_range: -0.5..0.5)
      expect(index).not_to be_valid
    end

    it "is invalid for a tolerance range greater than 1" do
      index = build(:release_index, tolerable_range: 0.5..1.5)
      expect(index).not_to be_valid
    end

    it "is valid for a tolerance range between 0 and 1" do
      index = build(:release_index, tolerable_range: 0.1..0.9)
      expect(index).to be_valid
    end
  end

  describe "#score" do
    it "computes the reldex score" do
      reldex = create(:release_index, tolerable_range: 0.5..0.8)
      metrics = {
        hotfixes: 1,
        rollout_fixes: 1,
        rollout_duration: 7,
        duration: 12,
        stability_duration: 5,
        stability_changes: 5
      }

      score = reldex.score(**metrics)
      expect(score.reldex).to eq 0.550
    end

    it "computes the reldex grade" do
      reldex = create(:release_index, tolerable_range: 0.5..0.8)
      metrics = {
        hotfixes: 1,
        rollout_fixes: 1,
        rollout_duration: 7,
        duration: 12,
        stability_duration: 5,
        stability_changes: 5
      }

      score = reldex.score(**metrics)
      expect(score.grade).to eq :acceptable
    end
  end
end
