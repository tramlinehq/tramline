module SiteExtensions
  require "ostruct"

  def self.determine_git_ref
    ref = begin
      ENV["GIT_REF"] || `git rev-parse --short HEAD`.chomp
    rescue StandardError
      "unknown"
    end
    tat = begin
      ENV["GIT_REF_AT"] || `git show -s --format=%ci HEAD`.chomp
    rescue StandardError
      Time.now.utc.to_s
    end
    OpenStruct.new(ref: ref, at: tat)
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
