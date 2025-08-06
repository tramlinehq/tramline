module Versionable
  using RefinedString

  def next_version(major_only: false, patch_only: false)
    raise ArgumentError, "both major and patch cannot be true" if major_only && patch_only
    version = version_current.to_semverish
    version_current.ver_bump(bump_term(version, major_only:, patch_only:), strategy: versioning_strategy)
  end

  def next_to_next_version(major_only: false, patch_only: false)
    version = version_current.to_semverish
    next_version(major_only: major_only, patch_only: patch_only)
      .ver_bump(bump_term(version, major_only:, patch_only:), strategy: versioning_strategy)
  end

  def future_version
    version = next_version.to_semverish
    patch = version.patch
    patch = format "%02d", patch[0..1].to_i + 1 # ignore seq number
    VersioningStrategies::Semverish.new([version.major, version.minor, patch].join(".")).to_s
  end

  private

  def bump_term(version, major_only: false, patch_only: false)
    patch_only = true if patch_version_bump_only && !major_only
    if patch_only && version.proper?
      :patch
    else
      major_only ? :major : :minor
    end
  end
end
