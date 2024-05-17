class V2::PlatformOverviewComponent < V2::BaseReleaseComponent
  SIZES = %i[default compact].freeze

  def initialize(release, size: :default, occupy: true)
    raise ArgumentError, "Invalid size: #{size}" unless SIZES.include?(size)
    @release = release
    @size = size
    @occupy = occupy
    super(@release)
  end

  attr_reader :release, :occupy, :size

  def show_ci_info
    @size != :compact
  end

  def monitoring_size
    cross_platform? ? size : :default
  end
end
