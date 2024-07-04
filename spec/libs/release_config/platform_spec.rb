# frozen_string_literal: true

require "rails_helper"

describe ReleaseConfig::Platform do
  describe "#distributions?" do
    it "is true when distributions are present" do
      platform_config = described_class.new({distributions: [{number: 1}]})
      expect(platform_config.distributions?).to eq(true)
    end

    it "is false when distributions are not present" do
      expect(described_class.new({distributions: nil}).distributions?).to eq(false)
      expect(described_class.new({distributions: [{}]}).distributions?).to eq(false)
    end
  end

  describe "#distributions" do
    it "returns distributions" do
      platform_config = described_class.new({distributions: [{number: 1}]})
      expect(platform_config.distributions.value).to eq([{number: 1}])
    end

    it "return first distribution" do
      platform_config = described_class.new({distributions: [{number: 1}, {number: 2}]})
      expect(platform_config.distributions.first.value).to eq({number: 1})
    end

    it "returns last distribution" do
      platform_config = described_class.new({distributions: [{number: 1}, {number: 2}, {number: 3}]})
      expect(platform_config.distributions.last.value).to eq({number: 3})
    end

    it "finds by number" do
      platform_config = described_class.new({distributions: [{number: 1}, {number: 2}, {number: 3}]})
      expect(platform_config.distributions.find_by_number(2)).to eq({number: 2})
    end

    it "allows fetching next distribution" do
      platform_config = described_class.new({distributions: [{number: 1}, {number: 2}, {number: 3}]})
      expect(platform_config.distributions.first.next.value).to eq({number: 2})
    end
  end
end
