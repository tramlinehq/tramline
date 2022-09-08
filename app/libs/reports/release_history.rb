module Reports
  class ReleaseHistory
    def self.call(**args)
      new(**args).call
    end

    def initialize(app:, period:, last:)
      @app = app
      @period = period || :month
      @last = last
    end

    def call
      app.runs.finished.group_by_period(period, :completed_at, last: last, current: true).count
    end

    private

    attr_reader :app, :period, :last
  end
end
