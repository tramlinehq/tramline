# frozen_string_literal: true

require "rails_helper"

describe ReleaseConfig::Platform do
  describe "#submissions?" do
    it "is true when submissions are present" do
      platform_config = described_class.new({submissions: [{number: 1}]})
      expect(platform_config.submissions?).to be(true)
    end

    it "is false when submissions are not present" do
      expect(described_class.new({submissions: nil}).submissions?).to be(false)
      expect(described_class.new({submissions: [{}]}).submissions?).to be(false)
    end
  end

  describe "#submissions" do
    it "returns submissions" do
      platform_config = described_class.new({submissions: [{number: 1}]})
      expect(platform_config.submissions.value).to match([{number: 1}])
    end

    it "return first submission" do
      platform_config = described_class.new({submissions: [{number: 1}, {number: 2}]})
      expect(platform_config.submissions.first.value).to match({number: 1})
    end

    it "returns last submission" do
      platform_config = described_class.new({submissions: [{number: 1}, {number: 2}, {number: 3}]})
      expect(platform_config.submissions.last.value).to match({number: 3})
    end

    it "finds by number" do
      platform_config = described_class.new({submissions: [{number: 1}, {number: 2}, {number: 3}]})
      expect(platform_config.submissions.fetch_by_number(2).value).to match({number: 2})
    end

    it "allows fetching next submission" do
      platform_config = described_class.new({submissions: [{number: 1}, {number: 2}, {number: 3}]})
      expect(platform_config.submissions.first.next.value).to match({number: 2})
    end
  end
end
