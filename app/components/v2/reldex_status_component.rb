class V2::ReldexStatusComponent < V2::BaseComponent
  def initialize(release:, reldex_score:)
    raise ArgumentError, "reldex score is not a Score object" unless reldex_score.class.name == "ReleaseIndex::Score"
    @release = release
    @reldex_score = reldex_score
  end

  def final_score
    @reldex_score.value
  end

  def grade
    @reldex_score.grade
  end

  delegate :release_version, to: :@release
end
