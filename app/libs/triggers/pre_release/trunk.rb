class Triggers::PreRelease
  class Trunk
    def self.call(release, _release_branch)
      new(release).call
    end

    def initialize(release)
      @release = release
    end

    def call
      create_version_tag
    end

    private

    attr_reader :release
    delegate :train, to: :release
    delegate :working_branch, to: :train
    delegate :logger, to: Rails

    def create_version_tag
      GitHub::Result.new do
        head_sha = train.vcs_provider.branch_head_sha(working_branch)
        tag_name = "v#{train.next_version}"

        train.vcs_provider.create_tag!(tag_name, head_sha).then do |value|
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
end
