module SiteExtensions
  require "ostruct"

  def self.determine_git_ref
    OpenStruct.new(git_ref: `git rev-parse --short HEAD`.chomp, git_ref_at: `git show -s --format=%ci HEAD`.chomp)
  end

  GIT_REF = determine_git_ref

  def git_ref
    GIT_REF.git_ref
  end

  def git_ref_at
    Time.parse GIT_REF.git_ref_at
  end
end

# Add on to the top level application constant to make things easy
Site.extend SiteExtensions
