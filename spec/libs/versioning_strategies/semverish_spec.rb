require "rails_helper"

describe VersioningStrategies::Semverish do
  describe "validity" do
    it "follows the semver rules for every term" do
      expect(described_class.new("1.2.1").to_s).to eq("1.2.1")
      expect(described_class.new("1.2.0").to_s).to eq("1.2.0")
      expect(described_class.new("0.2").to_s).to eq("0.2")
    end

    it "rejects invalids" do
      expect { described_class.new("1.02") }.to raise_error(ArgumentError)
      expect { described_class.new("01.02") }.to raise_error(ArgumentError)
      expect { described_class.new("1.02.1") }.to raise_error(ArgumentError)
      expect { described_class.new("01.2.1") }.to raise_error(ArgumentError)
    end

    it "rejects pre-release and build metadata" do
      expect { described_class.new("1.2.1+1") }.to raise_error(ArgumentError)
      expect { described_class.new("1.2.1-alpha") }.to raise_error(ArgumentError)
      expect { described_class.new("1.2.1-alpha+1") }.to raise_error(ArgumentError)
    end
  end

  describe "comparisons" do
    context "when semver" do
      it "compares using > or <" do
        v1 = described_class.new("1.2.1")
        v2 = described_class.new("1.2.0")
        v3 = described_class.new("1.2.0")

        expect(v1 > v2).to be(true)
        expect(v1 < v2).to be(false)
        expect(v2 <= v3).to be(true)
        expect(v3 >= v2).to be(true)
      end

      it "compares using ==" do
        v1 = described_class.new("1.2.1")
        v2 = described_class.new("1.2.1")
        v3 = described_class.new("1.2.2")

        expect(v1 == v2).to be(true)
        expect(v2 != v3).to be(true)
        expect(v1 == v3).to be(false)
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

    context "when calendar (year_and_next_week) version" do
      it "compares using > or <" do
        v1 = described_class.new("1.2452.1")
        v2 = described_class.new("1.2452.0")
        v3 = described_class.new("1.2452.0")

        expect(v1 > v2).to be(true)
        expect(v1 < v2).to be(false)
        expect(v2 <= v3).to be(true)
        expect(v3 >= v2).to be(true)
      end

      it "compares using ==" do
        v1 = described_class.new("0.2452.1")
        v2 = described_class.new("0.2452.1")
        v3 = described_class.new("1.2452.1")

        expect(v1 == v2).to be(true)
        expect(v2 != v3).to be(true)
        expect(v1 == v3).to be(false)
      end

      it "does not compare a partial and a proper semver" do
        bigger = described_class.new("0.2452.1")
        smaller = described_class.new("0.2452")

        expect { bigger > smaller }.to raise_error(ArgumentError)
      end

      it "determines sort order" do
        v1 = described_class.new("0.2452.2")
        v2 = described_class.new("1.2452.0")
        v3 = described_class.new("0.2252.1")
        v4 = described_class.new("0.2552.1")

        pv1 = described_class.new("0.2452")
        pv2 = described_class.new("0.2452")
        pv3 = described_class.new("0.2202")
        pv4 = described_class.new("0.2203")
        pv5 = described_class.new("0.2201")

        expect([v1, v2, v3, v4].sort).to eq([v3, v1, v4, v2])
        expect([pv1, pv2, pv3, pv4, pv5].sort).to eq([pv5, pv3, pv4, pv1, pv2])
      end
    end
  end

  describe "#bump!" do
    context "when semverish based on positive numbers" do
      let(:semverish) { described_class.new("1.2.1") }

      it "bumps up major" do
        expect(semverish.bump!(:major, strategy: :semver).to_s).to eq("2.0.0")
      end

      it "bumps up minor" do
        expect(semverish.bump!(:minor, strategy: :semver).to_s).to eq("1.3.0")
      end

      it "bumps up patch" do
        expect(semverish.bump!(:patch, strategy: :semver).to_s).to eq("1.2.2")
      end
    end

    context "with partial semverish based on positive numbers" do
      let(:partial_semverish) { described_class.new("1.2") }

      it "bumps up major" do
        expect(partial_semverish.bump!(:major, strategy: :semver).to_s).to eq("2.0")
      end

      it "bumps up minor" do
        expect(partial_semverish.bump!(:minor, strategy: :semver).to_s).to eq("1.3")
      end

      it "does not do anything if patch" do
        expect(partial_semverish.bump!(:patch, strategy: :semver).to_s).to eq("1.2")
      end
    end

    context "when calendar (year_and_next_week) version" do
      let(:year_and_next_week) { described_class.new("0.2347.0") }
      let(:the_time) { Time.new(2023, 12, 1, 0, 0, 0, '+12:00') }

      it "bumps up major and keeps minor intact" do
        travel_to(the_time) do
          expect(year_and_next_week.bump!(:major, strategy: :year_and_next_week).to_s).to eq("1.2349.0")
        end
      end

      it "bumps up minor" do
        travel_to(the_time) do
          expect(year_and_next_week.bump!(:minor, strategy: :year_and_next_week).to_s).to eq("0.2349.0")
        end
      end

      it "does not do anything if patch" do
        expect(year_and_next_week.bump!(:patch, strategy: :year_and_next_week).to_s).to eq("0.2347.1")
      end
    end
  end
end
