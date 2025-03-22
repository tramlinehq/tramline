class Triggers::Branch
  BranchCreateError = Class.new(Triggers::Errors)

  def self.call(release, source_branch, new_branch, source_type, stamp_data, stamp_type)
    new(release, source_branch, new_branch, source_type, stamp_data, stamp_type).call
  end

  def initialize(release, source_branch, new_branch, source_type, stamp_data, stamp_type)
    @release = release
    @train = release.train
    @source_branch = source_branch
    @new_branch = new_branch
    @source_type = source_type
    @stamp_data = stamp_data
    @stamp_type = stamp_type
  end

  attr_reader :release, :train, :source_branch, :new_branch, :source_type, :stamp_data, :stamp_type
  delegate :logger, to: Rails

  def call
    GitHub::Result.new do
      train.create_branch!(source_branch, new_branch, source_type:).then do |value|
        release.event_stamp_now!(reason: stamp_type, kind: :success, data: stamp_data)
        value
      end
    rescue Installations::Error => ex
      if ex.reason == :tag_reference_already_exists
        logger.debug { "Branch already exists: #{new_branch}" }
        nil
      else
        raise BranchCreateError, "Could not create branch #{new_branch} from #{source_branch}"
      end
    end
  end
end
