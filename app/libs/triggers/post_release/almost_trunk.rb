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
      release.reload.finish! if create_tag.ok?
    end

    private

    attr_reader :train, :release

    def create_tag
      GitHub::Result.new do
        train.create_tag!(release.branch_name)
      rescue Installations::Errors::TagReferenceAlreadyExists
        Rails.logger.debug { "Release finalization: did not create tag, since #{train.tag_name} already existed" }
      rescue Installations::Errors::TaggedReleaseAlreadyExists
        Rails.logger.debug { "Release finalization: skipping since tagged release for #{train.tag_name} already exists!" }
      end
    end

    def stamp_data
      {tag: release.tag_name}
    end
  end
end
