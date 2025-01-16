# frozen_string_literal: true

class LiveRelease::PreProdRelease::HeaderComponent < BaseComponent
  include Memery

  def initialize(release_platform_run, pre_prod_release)
    @release_platform_run = release_platform_run
    @pre_prod_release = pre_prod_release
  end

  attr_reader :release_platform_run, :pre_prod_release
  delegate :latest_events, to: :pre_prod_release, allow_nil: true

  memoize def events
    return [] unless latest_events
    latest_events.flat_map do |event|
      {
        type: event.kind.to_sym,
        description: event.message,
        timestamp: time_format(event.event_timestamp, with_year: false)
      }
    end
  end

  def grids
    return "grid grid-cols-2" if events.present?
    "grid grid-cols-1"
  end
end
