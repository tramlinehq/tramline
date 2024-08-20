# frozen_string_literal: true

class V2::PlatformOverviewV2Component < V2::BaseReleaseComponent
  SIZES = %i[default compact].freeze

  def initialize(release, size: :default, occupy: true, show_monitoring: true)
    raise ArgumentError, "Invalid size: #{size}" unless SIZES.include?(size)
    @release = release
    @size = size
    @occupy = occupy
    @show_monitoring = show_monitoring
    super(@release)
  end

  attr_reader :release, :occupy, :size, :show_monitoring

  def show_build
    @size != :compact
  end

  def monitoring_size
    cross_platform? ? size : :default
  end
end
