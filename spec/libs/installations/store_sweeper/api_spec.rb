require "rails_helper"

describe Installations::StoreSweeper::Api, type: :integration do
  let(:api) { described_class.new }

  describe "#tsearch" do
    let(:search_term) { "whatsapp" }
    let(:fixture_response) { JSON.parse(File.read("spec/fixtures/store_sweeper/search_results.json")) }

    context "with valid parameters" do
      it "returns search results from both stores" do
        stub_request(:get, described_class::TSEARCH_URL)
          .with(query: {searchTerm: search_term, numCount: 50, lang: "en", country: "us"})
          .to_return(status: 200, body: fixture_response.to_json, headers: {"Content-Type" => "application/json"})

        result = api.tsearch(search_term: search_term)

        expect(result).to be_a(Hash)
        expect(result["results"]).to be_an(Array)
        expect(result["metadata"]).to be_a(Hash)
      end

      it "supports custom parameters" do
        stub_request(:get, described_class::TSEARCH_URL)
          .with(query: {searchTerm: "telegram", numCount: 10, lang: "es", country: "mx"})
          .to_return(status: 200, body: fixture_response.to_json, headers: {"Content-Type" => "application/json"})

        result = api.tsearch(search_term: "telegram", num_count: 10, lang: "es", country: "mx")

        expect(result).to be_a(Hash)
      end
    end

    context "with invalid parameters" do
      it "returns empty results when search_term is blank" do
        result = api.tsearch(search_term: "")

        expect(result).to eq({"results" => [], "metadata" => {"count" => 0}})
      end

      it "returns empty results when num_count is out of range" do
        result = api.tsearch(search_term: "test", num_count: 0)
        expect(result).to eq({"results" => [], "metadata" => {"count" => 0}})

        result = api.tsearch(search_term: "test", num_count: 251)
        expect(result).to eq({"results" => [], "metadata" => {"count" => 0}})
      end
    end

    context "when API returns error" do
      it "returns empty results and logs error" do
        stub_request(:get, described_class::TSEARCH_URL)
          .with(query: {searchTerm: search_term, numCount: 50, lang: "en", country: "us"})
          .to_return(status: 500, body: "Internal Server Error")

        result = api.tsearch(search_term: search_term)

        expect(result).to eq({"results" => [], "metadata" => {"count" => 0}})
      end
    end

    context "when API connection fails" do
      it "returns empty results and logs error" do
        stub_request(:get, described_class::TSEARCH_URL)
          .with(query: {searchTerm: search_term, numCount: 50, lang: "en", country: "us"})
          .to_timeout

        result = api.tsearch(search_term: search_term)

        expect(result).to eq({"results" => [], "metadata" => {"count" => 0}})
      end
    end
  end

  describe "#healthy?" do
    context "when service is healthy" do
      it "returns true" do
        stub_request(:get, described_class::HEALTH_URL)
          .to_return(status: 200, body: "OK")

        expect(api.healthy?).to be true
      end
    end

    context "when service is unhealthy" do
      it "returns false" do
        stub_request(:get, described_class::HEALTH_URL)
          .to_return(status: 503, body: "Service Unavailable")

        expect(api.healthy?).to be false
      end
    end

    context "when connection fails" do
      it "returns false and logs error" do
        stub_request(:get, described_class::HEALTH_URL)
          .to_timeout

        expect(api.healthy?).to be false
      end
    end
  end
end
