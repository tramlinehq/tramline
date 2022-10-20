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
      release.reload.finish! if create_tag.ok? && create_release.ok?
    end

    private

    Result = Struct.new(:ok?, :error, :value, keyword_init: true)
    attr_reader :train, :release
    delegate :tag_name, to: :train

    def create_tag
      begin
        Result.new(ok?: true, value: train.create_tag!(release.branch_name))
      rescue Installations::Errors::TagReferenceAlreadyExists
        release.event_stamp!(reason: :tag_reference_already_exists, kind: :notice, data: {})
      end

      Result.new(ok?: true)
    end

    def create_release
      begin
        train.create_release!(tag_name)
      rescue Installations::Errors::TaggedReleaseAlreadyExists
        release.event_stamp!(reason: :tagged_release_already_exists, kind: :notice, data: { tag: tag_name })
      end

      Result.new(ok?: true)
    end
  end
end
