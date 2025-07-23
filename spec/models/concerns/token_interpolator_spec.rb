require "rails_helper"

# Test class to include TokenInterpolator
class TestModelWithPattern
  include ActiveModel::Model
  include ActiveModel::Validations
  include TokenInterpolator

  validate :validate_token_fields, if: :validate_tokens?

  attr_accessor :pattern_field

  def token_fields
    {
      pattern_field: {
        value: pattern_field,
        allowed_tokens: %w[trainName releaseVersion releaseStartDate]
      }
    }
  end
end

describe TokenInterpolator do
  let(:model) { TestModelWithPattern.new }

  describe "#interpolate" do
    it "substitutes tokens in pattern string" do
      pattern = "release/~trainName~/~releaseVersion~"
      tokens = {trainName: "my-train", releaseVersion: "1.2.3"}

      result = model.interpolate_tokens(pattern, tokens)

      expect(result).to eq("release/my-train/1.2.3")
    end

    it "handles empty values gracefully" do
      pattern = "release/~trainName~/~releaseVersion~"
      tokens = {trainName: "my-train", releaseVersion: ""}

      result = model.interpolate_tokens(pattern, tokens)

      expect(result).to eq("release/my-train/~releaseVersion~")
    end

    it "returns original string if no pattern" do
      pattern = "simple-string"
      tokens = {trainName: "my-train"}

      result = model.interpolate_tokens(pattern, tokens)

      expect(result).to eq("simple-string")
    end

    it "returns blank string if input is blank" do
      result = model.interpolate_tokens("", {trainName: "my-train"})
      expect(result).to eq("")

      result = model.interpolate_tokens(nil, {trainName: "my-train"})
      expect(result).to be_nil
    end
  end

  describe "validation" do
    it "validates only available tokens are used" do
      model.pattern_field = "release/~unknownToken~"

      expect(model).not_to be_valid
      expect(model.errors[:pattern_field]).to include("contains unknown tokens: ~unknownToken~")
    end

    it "is valid when using available tokens" do
      model.pattern_field = "release/~trainName~/build"

      expect(model).to be_valid
    end

    it "is valid when no pattern is set" do
      model.pattern_field = nil

      expect(model).to be_valid
    end

    it "is valid when pattern has no tokens" do
      model.pattern_field = "simple/path"

      expect(model).to be_valid
    end

    it "skips validation when pattern is blank" do
      model.pattern_field = ""

      expect(model).to be_valid
    end

    it "validates multiple invalid tokens" do
      model.pattern_field = "release/~unknownToken~/~anotherBadToken~"

      expect(model).not_to be_valid
      expect(model.errors[:pattern_field]).to include("contains unknown tokens: ~unknownToken~, ~anotherBadToken~")
    end

    it "is valid with multiple available tokens" do
      model.pattern_field = "release/~trainName~/~releaseVersion~"

      expect(model).to be_valid
    end

    it "validates field-specific allowed tokens" do
      # buildNumber is available globally but not allowed for pattern_field
      model.pattern_field = "release/~buildNumber~"

      expect(model).not_to be_valid
      expect(model.errors[:pattern_field]).to include("contains unknown tokens: ~buildNumber~")
    end
  end

  describe "token formatting" do
    it "applies trainName formatting (parameterizes)" do
      pattern = "release/~trainName~"
      tokens = {trainName: "My Complex Train Name"}

      result = model.interpolate_tokens(pattern, tokens)

      expect(result).to eq("release/my-complex-train-name")
    end

    it "applies releaseVersion formatting (strips whitespace)" do
      pattern = "release/~releaseVersion~"
      tokens = {releaseVersion: "  1.2.3  "}

      result = model.interpolate_tokens(pattern, tokens)

      expect(result).to eq("release/1.2.3")
    end

    it "applies releaseStartDate formatting for Date objects" do
      pattern = "release/~releaseStartDate~"
      date_obj = Date.new(2023, 12, 25)
      tokens = {releaseStartDate: date_obj}

      result = model.interpolate_tokens(pattern, tokens)

      expect(result).to eq("release/2023-12-25")
    end

    it "preserves releaseStartDate for pre-formatted strings" do
      pattern = "release/~releaseStartDate~"
      tokens = {releaseStartDate: "%Y-%m-%d"}

      result = model.interpolate_tokens(pattern, tokens)

      expect(result).to eq("release/%Y-%m-%d")
    end
  end
end
