class V2::PlatformLevelSubmissionComponent < V2::BaseReleaseComponent
  def initialize(release)
    @release = release
    super(@release)
  end
end
