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
        release.event_stamp!(reason: :tag_reference_already_exists, kind: :notice, data: {})
      rescue Installations::Errors::TaggedReleaseAlreadyExists
        release.event_stamp!(reason: :tagged_release_already_exists, kind: :notice, data: {tag: release.tag_name})
      end
    end
  end
end
