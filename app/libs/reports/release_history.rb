module Reports
  class ReleaseHistory
    def self.call(**args)
      new(**args).call
    end

    FORMAT = "%b %Y"

    def initialize(app:, period:, last:)
      @app = app
      @period = period || :month
      @last = last
    end

    def call
      app
        .releases
        .finished
        .group_by_period(period, :completed_at, last: last, current: true, format: FORMAT)
        .count
    end

    private

    attr_reader :app, :period, :last
  end
end
