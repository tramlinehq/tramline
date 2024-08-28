class Coordinators::StartFinalizingRelease
  def self.call(release, force_finalize = false)
    new(release, force_finalize).call
  end

  def initialize(release, force_finalize = false)
    @release = release
    @force_finalize = force_finalize
  end

  def call
    with_lock do
      raise "release is not ready to be finalized" unless Release::FINALIZE_STATES.include?(release.status)
      raise "release is not ready to be finalized" unless release.ready_to_be_finalized?
      release.start_post_release_phase!
    end

    V2::FinalizeReleaseJob.perform_later(release.id, force_finalize)
  end

  attr_reader :release, :force_finalize
  delegate :with_lock, to: :release
end
