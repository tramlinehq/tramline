# == Schema Information
#
# Table name: builds
#
#  id                      :uuid             not null, primary key
#  build_number            :string
#  external_name           :string
#  generated_at            :datetime
#  sequence_number         :integer          default(0), not null, indexed
#  size_in_bytes           :integer
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
  include Passportable

  belongs_to :release_platform_run
  belongs_to :commit
  belongs_to :workflow_run
  has_one :artifact, class_name: "BuildArtifact", dependent: :nullify, inverse_of: :build

  # TODO: Remove this, don't think this is how it should be referenced
  has_one :app_store_submission, dependent: :nullify, inverse_of: :build
  has_one :play_store_submission, dependent: :nullify, inverse_of: :build

  delegate :android?, :ios?, :ci_cd_provider, to: :release_platform_run
  delegate :artifacts_url, :build_artifact_name_pattern, to: :workflow_run

  before_create :set_sequence_number
  after_create :attach_artifact!

  # TODO: Remove this, don't think this is how it should be referenced
  def store_submission
    if android?
      play_store_submission
    elsif ios?
      app_store_submission
    else
      raise ArgumentError, "Unknown platform"
    end
  end

  def display_name
    "#{version_name} (#{build_number})"
  end

  def has_artifact?
    artifact.present?
  end

  def attach_artifact!
    return if artifacts_url.blank?

    get_build_artifact => { artifact:, stream: }
    return if artifact.blank?

    self.generated_at = artifact[:generated_at] || workflow_run.finished_at
    self.size_in_bytes = artifact[:size_in_bytes]
    self.external_name = artifact[:name]
    self.external_id = artifact[:id]

    stream.with_open do |artifact_stream|
      build.build_artifact.save_file!(artifact_stream)
      artifact_stream.file.rewind
      self.slack_file_id = train.upload_file_for_notifications!(artifact_stream.file, artifact.get_filename)
    end

    save!
    # FIXME notify on create
    # notify!("A new build is available!", :build_available, notification_params, slack_file_id, display_name) if slack_file_id
  end

  private

  def set_sequence_number
    self.sequence_number = release_platform_run.next_build_sequence_number
  end

  def get_build_artifact
    ci_cd_provider.get_artifact_v2(artifacts_url, build_artifact_name_pattern)
  end
end
