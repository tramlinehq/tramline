module Versionable
  using RefinedString

  def next_version(has_major_bump: false, patch_only: false)
    raise ArgumentError, "both major and patch cannot be true" if has_major_bump && patch_only
    version = version_current.to_semverish

    bump_term =
      if patch_only && version.proper?
        :patch
      else
        has_major_bump ? :major : :minor
      end

    version_current.ver_bump(bump_term)
  end
end
