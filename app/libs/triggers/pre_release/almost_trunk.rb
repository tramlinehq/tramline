class Triggers::PreRelease
  class AlmostTrunk
    def self.call(release, release_branch)
      new(release, release_branch).call
    end

    def initialize(release, release_branch)
      @release = release
      @release_branch = release_branch
    end

    def call
      create_branch
    end

    private

    attr_reader :release, :release_branch
    delegate :train, :hotfix?, :new_hotfix_branch?, to: :release
    delegate :working_branch, to: :train
    delegate :logger, to: Rails

    def create_branch
      GitHub::Result.new do
        source = source_ref
        train.create_branch!(source[:ref], release_branch, source_type: source[:type]).then do |value|
          stamp_data = {working_branch: source[:ref], release_branch:}
          release.event_stamp_now!(reason: :release_branch_created, kind: :success, data: stamp_data)
          GitHub::Result.new { value }
        end
      rescue Installations::Error => ex
        raise unless ex.reason == :tag_reference_already_exists
        logger.debug { "Pre-release branch already exists: #{release_branch}" }
      end
    end

    def hotfix_branch?
      hotfix? && new_hotfix_branch?
    end

    def source_ref
      if hotfix_branch?
        {
          ref: release.hotfixed_from.end_ref,
          type: :tag
        }
      else
        {
          ref: working_branch,
          type: :branch
        }
      end
    end
  end
end
