class V2::ReldexStatusComponent < V2::BaseComponent
  def initialize(release)
    @release = release
  end

  delegate :release_version, to: :@release
end
