class PlatformViewComponent < BaseComponent
  def initialize(release, occupy: true, detail: true)
    @release = ReleasePresenter.new(release, self)
    @occupy = occupy
    @detail = detail
    super(@release)
  end

  delegate :platform_runs, :cross_platform?, to: :@release

  def grid_size
    return "grid-cols-2" if platform_runs.size > 1
    return "grid-cols-1" if @occupy
    "grid-cols-1 w-2/3"
  end

  def runs
    platform_runs.each do |run|
      yield(run)
    end
  end
end
