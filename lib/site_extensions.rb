module SiteExtensions
  require "ostruct"

  def self.determine_git_ref
    ref = ENV["GIT_REF"].presence || git_output("rev-parse", "--short", "HEAD") || "🚫"
    tat = ENV["GIT_REF_AT"].presence || git_output("show", "-s", "--format=%ci", "HEAD") || Time.now.utc.to_s
    OpenStruct.new(ref: ref, at: tat)
  end

  # Shell out to git, tolerating its absence. The production image ships no git,
  # and `kamal app exec` (docker exec) doesn't run the entrypoint that exports
  # GIT_REF from .git_ref — so console/exec sessions have neither the env var nor
  # the binary. Without the rescue the missing binary raises Errno::ENOENT and
  # crashes app load; here we just fall back to ENV or the default.
  #
  # Array-form IO.popen (no shell) so a stray metacharacter can't run — and so
  # Brakeman's Execute check doesn't flag an interpolated command string.
  def self.git_output(*args)
    IO.popen(["git", *args], err: File::NULL, &:read).chomp.presence
  rescue
    nil
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
