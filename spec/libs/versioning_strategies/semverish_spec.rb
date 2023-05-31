require "rails_helper"

describe VersioningStrategies::Semverish do
  describe "validity" do
    it "follows the semver rules for every term" do
      expect(described_class.new("1.2.1").to_s).to eq("1.2.1")
      expect(described_class.new("1.2.0").to_s).to eq("1.2.0")
      expect(described_class.new("0.2").to_s).to eq("0.2")

      expect { described_class.new("1.02").to_s }.to raise_error(ArgumentError)
      expect { described_class.new("01.02").to_s }.to raise_error(ArgumentError)
      expect { described_class.new("1.02.1").to_s }.to raise_error(ArgumentError)
      expect { described_class.new("01.2.1").to_s }.to raise_error(ArgumentError)
      expect { described_class.new("1.2.1+1").to_s }.to raise_error(ArgumentError)
      expect { described_class.new("1.2.1-alpha").to_s }.to raise_error(ArgumentError)
      expect { described_class.new("1.2.1-alpha+1").to_s }.to raise_error(ArgumentError)
    end
  end

  describe "comparisons" do
    subject(:partial_semverish) { described_class.new("1.2") }

    let(:semverish) { described_class.new("1.2.1") }

    it "compares using > or <" do
      v1 = described_class.new("1.2.1")
      v2 = described_class.new("1.2.0")
      v3 = described_class.new("1.2.0")

      expect(v1 > v2).to eq(true)
      expect(v1 < v2).to eq(false)
      expect(v2 <= v3).to eq(true)
      expect(v3 >= v2).to eq(true)
    end

    it "compares using ==" do
      v1 = described_class.new("1.2.1")
      v2 = described_class.new("1.2.1")
      v3 = described_class.new("1.2.2")

      expect(v1 == v2).to eq(true)
      expect(v2 != v3).to eq(true)
      expect(v1 == v3).to eq(false)
    end

    it "does not compare a partial and a proper semver" do
      bigger = described_class.new("1.2.1")
      smaller = described_class.new("1.2")

      expect { bigger > smaller }.to raise_error(ArgumentError)
    end

    it "determines sort order" do
      v1 = described_class.new("1.2.1")
      v2 = described_class.new("1.2.3")
      v3 = described_class.new("1.1.3")
      v4 = described_class.new("2.1.3")

      pv1 = described_class.new("2.1")
      pv2 = described_class.new("2.1")
      pv3 = described_class.new("1.2")
      pv4 = described_class.new("1.3")
      pv5 = described_class.new("0.1")

      expect([v1, v2, v3, v4].sort).to eq([v3, v1, v2, v4])
      expect([pv1, pv2, pv3, pv4, pv5].sort).to eq([pv5, pv3, pv4, pv1, pv2])
    end
  end

  describe "#bump!" do
    subject(:partial_semverish) { described_class.new("1.2") }

    let(:semverish) { described_class.new("1.2.1") }

    context "semverish" do
      context "updates the correct term based on positive numbers" do
        it "bumps up major" do
          expect(semverish.bump!(:major, template_type: :pn).to_s).to eq("2.0.0")
        end

        it "bumps up minor" do
          expect(semverish.bump!(:minor, template_type: :pn).to_s).to eq("1.3.0")
        end

        it "bumps up patch" do
          expect(semverish.bump!(:patch, template_type: :pn).to_s).to eq("1.2.2")
        end
      end
    end

    context "partial semverish" do
      context "updates the correct term based on positive numbers" do
        it "bumps up major" do
          expect(partial_semverish.bump!(:major, template_type: :pn).to_s).to eq("2.0")
        end

        it "bumps up minor" do
          expect(partial_semverish.bump!(:minor, template_type: :pn).to_s).to eq("1.3")
        end

        it "does not do anything if patch" do
          expect(partial_semverish.bump!(:patch, template_type: :pn).to_s).to eq("1.2")
        end
      end
    end
  end
end
