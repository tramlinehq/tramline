module Versionable
  using RefinedString

  def next_version(major_only: false, patch_only: false)
    raise ArgumentError, "both major and patch cannot be true" if major_only && patch_only
    version = version_current.to_semverish

    bump_term =
      if major_only && version.proper?
        :patch
      else
        major_only ? :major : :minor
      end

    version_current.ver_bump(bump_term)
  end
end
