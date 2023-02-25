class Triggers::PostRelease
  class AlmostTrunk
    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
      create_tag
    end

    private

    attr_reader :train, :release
    delegate :logger, to: Rails

    def create_tag
      GitHub::Result.new do
        train.create_tag!(release.branch_name)
      rescue Installations::Errors::TagReferenceAlreadyExists
        logger.debug("Release finalization: did not create tag, since #{train.tag_name} already existed")
      rescue Installations::Errors::TaggedReleaseAlreadyExists
        logger.debug("Release finalization: skipping since tagged release for #{train.tag_name} already exists!")
      end
    end
  end
end
