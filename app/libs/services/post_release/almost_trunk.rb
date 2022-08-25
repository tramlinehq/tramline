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
      release.mark_finished! if create_tag.success?
    end

    private

    Result = Struct.new(:success?, :err_message)

    attr_reader :train, :release

    def create_tag
      Automatons::Tag.dispatch!(train:, branch: release.branch_name)
    rescue Installations::Github::Error::ReferenceAlreadyExists
      release.event_stamp!(reason: :post_release_tag_reference_already_exists, kind: :notice, data: {})
    ensure
      Result.new(true)
    end
  end
end
