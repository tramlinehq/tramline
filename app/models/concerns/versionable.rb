module Versionable
  using RefinedString

  def next_version(major_only: false, patch_only: false)
    raise ArgumentError, "both major and patch cannot be true" if major_only && patch_only
    version = version_current.to_semverish
    version_current.ver_bump(bump_term(version, major_only:, patch_only:), strategy: versioning_strategy)
  end

  def next_to_next_version(major_only: false, patch_only: false)
    next_version(major_only: major_only, patch_only: patch_only)
      .ver_bump(bump_term(version, major_only:, patch_only:), strategy: versioning_strategy)
  end

  private

  def bump_term(version, major_only: false, patch_only: false)
    if patch_only && version.proper?
      :patch
    else
      major_only ? :major : :minor
    end
  end
end
