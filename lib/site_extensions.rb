module SiteExtensions
  require "ostruct"

  def self.determine_git_ref
    OpenStruct.new(ref: "1".chomp)
  end

  GIT_REF = determine_git_ref

  def git_ref
    GIT_REF.ref
  end

  def git_ref_at
    Time.zone.parse GIT_REF.at
  end
end

# Add on to the top level application constant to make things easy
Site.extend SiteExtensions
