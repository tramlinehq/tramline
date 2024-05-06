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
  has_one :play_store_submission, dependent: :nullify, inverse_of: :build
  has_one :app_store_submission, dependent: :nullify, inverse_of: :build

  def store_submission
    if release_platform_run.android?
      play_store_submission
    elsif release_platform_run.ios?
      app_store_submission
    else
      raise ArgumentError, "Unknown platform"
    end
  end

  def display_name
    "#{version_name} (#{build_number})"
  end
end
