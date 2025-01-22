require "rails_helper"

describe VersioningStrategies::Semverish do
  describe "validity (during init)" do
    [
      "1.2.1",
      "1.2.0",
      "0.2",
      "0.02",
      "1.02.0101",
      "1.02.0111",
      "1.02.1299",
      "1.2.0001",
      "1.11.01"
    ].each do |valid|
      it "follows the semverish rules #{valid}" do
        expect(described_class.new(valid).to_s).to eq(valid)
      end
    end

    [
      "01.02",
      "01.2.1",
      "01.002.1"
    ].each do |invalid|
      it "rejects invalid #{invalid}" do
        expect { described_class.new(invalid) }.to raise_error(ArgumentError)
      end
    end

    it "rejects pre-release and build metadata" do
      expect { described_class.new("1.2.1+1") }.to raise_error(ArgumentError)
      expect { described_class.new("1.2.1-alpha") }.to raise_error(ArgumentError)
      expect { described_class.new("1.2.1-alpha+1") }.to raise_error(ArgumentError)
    end
  end

  describe "comparisons" do
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

  describe "#bump!" do
    context "when semver" do
      context "with positive numbers" do
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
    end

    context "when calver" do
      let(:calver) { described_class.new("2015.12.1") }

      it "bumps up the day/month/year when bump is major" do
        the_time = Time.new(2016, 11, 2, 0, 0, 0, "+00:00")

        travel_to(the_time) do
          expect(calver.bump!(:major, strategy: :calver).to_s).to eq("2016.11.02")
        end
      end

      it "bumps up the day/month/year when bump is minor" do
        the_time = Time.new(2017, 10, 3, 0, 0, 0, "+00:00")

        travel_to(the_time) do
          expect(calver.bump!(:minor, strategy: :calver).to_s).to eq("2017.10.03")
        end
      end

      it "adds a sequence number when bump is patch" do
        the_time = Time.new(2015, 12, 1, 0, 0, 0, "+00:00")

        travel_to(the_time) do
          expect(calver.bump!(:patch, strategy: :calver).to_s).to eq("2015.12.0101")
        end
      end

      it "does not update the day/month/year only sequence number when bump is patch" do
        the_time = Time.new(2016, 11, 2, 0, 0, 0, "+00:00")

        travel_to(the_time) do
          expect(calver.bump!(:patch, strategy: :calver).to_s).to eq("2015.12.0101")
        end
      end
    end
  end

  describe "#valid?" do
    context "when calver" do
      [
        "2015.12.1110",
        "2015.12.01",
        "2015.12.3199",
        "2015.12.0101",
        "2015.12.0111",
        "2015.12.1299"
      ].each do |valid|
        it "follows the calver rules #{valid}" do
          expect(described_class.new(valid).valid?(strategy: :calver)).to be(true)
        end
      end

      [
        "30000.12.0101",
        "2015.12.0001",
        "3000.2.01",
        "3000.13.01",
        "2015.12.101",
        "2015.12.1100",
        "2015.12.3200",
        "2015.12.31100"
      ].each do |invalid|
        it "rejects invalid #{invalid}" do
          expect(described_class.new(invalid).valid?(strategy: :calver)).to be(false)
        end
      end
    end

    context "when semver" do
      [
        "1.2.1",
        "1.2.0",
        "0.2",
        "2.0",
        "12.12.999"
      ].each do |valid|
        it "follows the semver rules #{valid}" do
          expect(described_class.new(valid).valid?(strategy: :semver)).to be(true)
        end
      end

      [
        "1.02.1",
        "1.2.01"
      ].each do |invalid|
        it "rejects invalid #{invalid}" do
          expect(described_class.new(invalid).valid?(strategy: :semver)).to be(false)
        end
      end
    end
  end
end
