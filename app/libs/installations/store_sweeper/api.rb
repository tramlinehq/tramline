module Installations
  class StoreSweeper::Api
    include Loggable

    BASE_URL = "https://store-sweeper-946207521855.europe-west3.run.app"
    TSEARCH_URL = "#{BASE_URL}/tsearch"
    HEALTH_URL = "#{BASE_URL}/healthz"

    DEFAULT_NUM_COUNT = 50
    DEFAULT_LANG = "en"
    DEFAULT_COUNTRY = "us"

    # Initialize without authentication for now since /tsearch is for testing
    def initialize
      @client = HTTP.timeout(30)
    end

    # Test search endpoint (no authentication required)
    # TODO: move to authenticated endpoints later
    # @param search_term [String] The search query (required)
    # @param num_count [Integer] Number of results (1-250, default: 50)
    # @param lang [String] Language code (default: "en")
    # @param country [String] Country code in ISO 3166-1 alpha-2 format (default: "us")
    # @return [Hash] Search results with metadata or empty results on error
    def tsearch(search_term:, num_count: DEFAULT_NUM_COUNT, lang: DEFAULT_LANG, country: DEFAULT_COUNTRY)
      return empty_results if search_term.blank?
      return empty_results unless num_count.between?(1, 250)

      params = {
        searchTerm: search_term,
        numCount: num_count,
        lang: lang,
        country: country
      }

      response = @client.get(TSEARCH_URL, params: params)
      return empty_results unless response.status.success?

      JSON.parse(response.body.to_s)
    rescue HTTP::Error, Errno::ECONNREFUSED, Errno::ETIMEDOUT, JSON::ParserError => e
      elog(e, level: :error)
      empty_results
    end

    # Health check endpoint
    # @return [Boolean] true if service is healthy
    def healthy?
      response = @client.get(HEALTH_URL)
      response.status.success?
    rescue => e
      elog(e, level: :error)
      false
    end

    private

    def empty_results
      {"results" => [], "metadata" => {"count" => 0}}
    end
  end
end
