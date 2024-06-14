# == Schema Information
#
# Table name: builds
#
#  id                      :uuid             not null, primary key
#  build_number            :string
#  generated_at            :datetime
#  version_name            :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commit_id               :uuid             not null, indexed
#  release_platform_run_id :uuid             not null, indexed
#
class Build < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable

  belongs_to :release_platform_run
  belongs_to :commit
  has_one :artifact, class_name: "BuildArtifact", dependent: :nullify, inverse_of: :build
  has_one :app_store_submission, dependent: :nullify, inverse_of: :build
  has_one :play_store_submission, dependent: :nullify, inverse_of: :build

  delegate :android?, :ios?, to: :release_platform_run

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
end
