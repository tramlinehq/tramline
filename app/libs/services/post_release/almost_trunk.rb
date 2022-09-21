class Services::PostRelease
  class AlmostTrunk
    def self.call(release)
      new(release).call
    end

    def initialize(release)
      @release = release
      @train = release.train
    end

    def call
      release.mark_finished! if create_tag.ok?
    end

    private

    Result = Struct.new(:ok?, :error, :value, keyword_init: true)

    attr_reader :train, :release

    def create_tag
      begin
        train.create_tag!(release.branch_name)
      rescue Installations::Errors::TagReferenceAlreadyExists
        release.event_stamp!(reason: :tag_reference_already_exists, kind: :notice, data: {})
      end

      Result.new(ok?: true)
    end
  end
end
