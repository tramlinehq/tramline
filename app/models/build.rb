# == Schema Information
#
# Table name: builds
#
#  id                      :uuid             not null, primary key
#  build_number            :string
#  external_name           :string
#  generated_at            :datetime
#  sequence_number         :integer          default(0), not null, indexed
#  size_in_bytes           :bigint
#  version_name            :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commit_id               :uuid             not null, indexed
#  external_id             :string
#  release_platform_run_id :uuid             not null, indexed
#  slack_file_id           :string
#  workflow_run_id         :uuid             indexed
#
class Build < ApplicationRecord
  has_paper_trail
  include AASM
  include Loggable
  include Passportable
  # include Sandboxable

  belongs_to :release_platform_run
  belongs_to :commit
  belongs_to :workflow_run
  has_one :artifact, class_name: "BuildArtifact", dependent: :nullify, inverse_of: :build
  has_many :production_releases, dependent: :nullify, inverse_of: :build

  scope :internal, -> { joins(:workflow_run).where(workflow_run: {kind: WorkflowRun::KINDS[:internal]}) }
  scope :release_candidate, -> { joins(:workflow_run).where(workflow_run: {kind: WorkflowRun::KINDS[:release_candidate]}) }
  scope :ready, -> { where.not(generated_at: nil) }

  delegate :android?, :ios?, :ci_cd_provider, :train, to: :release_platform_run
  delegate :artifacts_url, :build_artifact_name_pattern, :kind, to: :workflow_run
  delegate :notify!, to: :train

  before_create :set_sequence_number

  def build_version = version_name

  def metadata = nil

  def display_name
    "#{version_name} (#{build_number})"
  end

  def has_artifact?
    artifact.present?
  end

  def attach_artifact!
    # return mock_attach_artifact if sandbox_mode?
    return if artifacts_url.blank?

    artifact_data = get_build_artifact

    if artifact_data.blank?
      update!(generated_at: workflow_run.finished_at)
      notify!("A new build is available!", :build_available_v2, notification_params)
      return
    end

    stream = artifact_data[:stream]
    artifact_metadata = artifact_data[:artifact]

    self.generated_at = artifact_metadata[:generated_at] || workflow_run.finished_at
    self.size_in_bytes = artifact_metadata[:size_in_bytes]
    self.external_name = artifact_metadata[:name]
    self.external_id = artifact_metadata[:id]

    stream.with_open do |artifact_stream|
      build_artifact.save_file!(artifact_stream)
      artifact_stream.file.rewind
      self.slack_file_id = train.upload_file_for_notifications!(artifact_stream.file, artifact.get_filename)
    end

    save!
    notify!("A new build is available!", :build_available_v2, notification_params, slack_file_id, display_name)
  end

  def notification_params
    workflow_run.notification_params.merge(
      artifact_present: has_artifact?
    )
  end

  private

  def set_sequence_number
    self.sequence_number = release_platform_run.next_build_sequence_number
  end

  def get_build_artifact
    ci_cd_provider.get_artifact_v2(artifacts_url, build_artifact_name_pattern, external_workflow_run_id: workflow_run.external_id)
  rescue Installations::Error => ex
    raise ex unless ex.reason == :artifact_not_found
    elog(e)
    nil
  end
end
