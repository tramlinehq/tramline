# frozen_string_literal: true

class PlatformOverviewComponent < BaseComponent
  SIZES = %i[default compact].freeze

  def initialize(release, size: :default, occupy: true, show_monitoring: true)
    raise ArgumentError, "Invalid size: #{size}" unless SIZES.include?(size)
    @release = ReleasePresenter.new(release, self)
    @size = size
    @occupy = occupy
    @show_monitoring = show_monitoring
    super(@release)
  end

  attr_reader :release, :occupy, :size, :show_monitoring
  delegate :platform_runs, :cross_platform?, to: :release

  def show_build
    @size != :compact
  end

  def monitoring_size
    cross_platform? ? size : :default
  end

  def platform_breakdown(run)
    Queries::PlatformBreakdown.call(run.id)
  end

  def store_versions?
    platform_runs.any? { |run| run.production_releases.exists? }
  end
end
