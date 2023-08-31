module Versionable
  using RefinedString

  def next_version(has_major_bump = false)
    bump_term = has_major_bump ? :major : :minor
    version_current.ver_bump(bump_term)
  end
end
