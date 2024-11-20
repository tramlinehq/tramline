class Triggers::Trunk
  def self.call(commit_hash, version, working_branch, vcs_provider)
    new(commit_hash, version, working_branch, vcs_provider).call
  end

  def initialize(commit_hash, version, working_branch, vcs_provider)
    @commit_hash = commit_hash
    @version = version
    @working_branch = working_branch
    @vcs_provider = vcs_provider
  end

  def call
    create_version_tag
  end

  private

  attr_reader :commit_hash, :version, :working_branch, :vcs_provider
  delegate :logger, to: Rails

  def create_version_tag
    GitHub::Result.new do
      tag_name = "v#{version}"
      vcs_provider.create_tag!(tag_name, commit_hash).then do |value|
        stamp_data = {working_branch:, tag_name:}
        release.event_stamp_now!(
          reason: :release_tag_created,
          kind: :success,
          data: stamp_data
        )
        GitHub::Result.new { value }
      end
    rescue Installations::Error => ex
      raise unless ex.reason == :tag_reference_already_exists
      logger.debug { "Pre-release tag already exists: #{tag_name}" }
    end
  end
end
