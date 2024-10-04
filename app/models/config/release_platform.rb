# == Schema Information
#
# Table name: release_platform_configs
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  release_platform_id :uuid             indexed
#
class Config::ReleasePlatform < ApplicationRecord
  self.table_name = "release_platform_configs"

  belongs_to :release_platform
  has_one :internal_workflow, -> { internal }, class_name: "Config::Workflow", inverse_of: :release_platform_config, dependent: :destroy
  has_one :release_candidate_workflow, -> { release_candidate }, class_name: "Config::Workflow", inverse_of: :release_platform_config, dependent: :destroy
  has_one :internal_release, -> { internal }, class_name: "Config::ReleaseStep", inverse_of: :release_platform_config, dependent: :destroy
  has_one :beta_release, -> { beta }, class_name: "Config::ReleaseStep", inverse_of: :release_platform_config, dependent: :destroy
  has_one :production_release, -> { production }, class_name: "Config::ReleaseStep", inverse_of: :release_platform_config, dependent: :destroy

  accepts_nested_attributes_for :internal_workflow, allow_destroy: true
  accepts_nested_attributes_for :release_candidate_workflow, allow_destroy: true
  accepts_nested_attributes_for :internal_release, allow_destroy: true
  accepts_nested_attributes_for :beta_release, allow_destroy: true
  accepts_nested_attributes_for :production_release, allow_destroy: true

  attribute :production_release_enabled, :boolean, default: false
  attribute :internal_release_enabled, :boolean, default: false
  attribute :beta_release_submissions_enabled, :boolean, default: false

  after_initialize :set_defaults

  validates :beta_release, presence: {message: :not_present}
  validates :release_candidate_workflow, presence: {message: :not_present}
  validate :workflow_identifiers
  validate :release_steps_presence
  validate :submission_uniqueness
  validate :internal_releases
  validate :beta_release_submissions

  delegate :platform, :app, to: :release_platform

  PRE_PROD_SUBMISSIONS_TO_PROVIDERS = {
    android: {
      GoogleFirebaseSubmission => :firebase_build_channel_provider,
      PlayStoreSubmission => :android_store_provider
    },
    ios: {
      GoogleFirebaseSubmission => :firebase_build_channel_provider,
      TestFlightSubmission => :ios_store_provider
    }
  }.freeze

  def self.from_json(json)
    json = json.with_indifferent_access
    release_config = new(json.except("workflows", "internal_release", "beta_release", "production_release", "id"))
    release_config.internal_workflow = Config::Workflow.from_json(json["workflows"]["internal"]) if json.dig("workflows", "internal").present?
    release_config.release_candidate_workflow = Config::Workflow.from_json(json["workflows"]["release_candidate"])
    release_config.internal_release = Config::ReleaseStep.from_json(json["internal_release"].merge("kind" => "internal")) if json["internal_release"]
    release_config.beta_release = Config::ReleaseStep.from_json(json["beta_release"].merge("kind" => "beta")) if json["beta_release"]
    release_config.production_release = Config::ReleaseStep.from_json(json["production_release"].merge("kind" => "production")) if json["production_release"]
    release_config
  end

  def set_defaults
    self.production_release_enabled = production_valid?
    self.internal_release_enabled = internal_valid?
    self.beta_release_submissions_enabled = beta_valid?
  end

  def as_json(options = {})
    {
      workflows: {
        internal: internal_workflow.as_json,
        release_candidate: release_candidate_workflow.as_json
      },
      internal_release: internal_release.as_json,
      beta_release: beta_release.as_json,
      production_release: production_release.as_json
    }
  end

  def pick_internal_workflow
    internal_workflow || release_candidate_workflow
  end

  def internal_release?
    internal_release.present?
  end

  def only_beta_release?
    !internal_release?
  end

  def beta_submissions?
    beta_release.submissions.present?
  end

  def auto_start_beta_release?
    separate_rc_workflow? && !beta_submissions?
  end

  def separate_rc_workflow?
    internal_workflow.present?
  end

  def production_release?
    production_release.present?
  end

  def allowed_pre_prod_submissions
    PRE_PROD_SUBMISSIONS_TO_PROVIDERS[platform.to_sym].each_with_object([]) do |(type, provider), submissions|
      provider = app.public_send(provider)
      next if provider.blank?

      submissions << {
        type: type,
        channels: provider.build_channels(with_production: false)
      }
    end
  end

  # Ensure that at least one of internal release, beta release, or production release is configured
  def release_steps_presence
    if !internal_valid? && !beta_valid? && !production_valid?
      errors.add(:base, :at_least_one_release_step)
    end
  end

  # Ensure that multiple workflows have unique identifiers
  def workflow_identifiers
    if internal_workflow&.identifier == release_candidate_workflow&.identifier
      errors.add(:base, :unique_workflows)
    end
  end

  # Ensure submissions across release steps (internal, beta, production) are unique by type and submission_external identifier
  def submission_uniqueness
    all_submissions = Set.new

    [internal_release, beta_release, production_release].compact.each do |release_step|
      release_step.submissions.each do |submission|
        submission_key = [submission.submission_type, submission.submission_external&.identifier].join("-")

        unless all_submissions.add?(submission_key)
          errors.add(:base, :unique_submissions)
          break
        end
      end
    end
  end

  # Ensure internal releases have workflows and submissions configured together
  def internal_releases
    workflow = internal_workflow.present? && !internal_workflow.marked_for_destruction?
    release = internal_valid? && internal_release.submissions&.reject(&:marked_for_destruction?).present?

    if workflow != release
      errors.add(:base, :internal_releases_are_incomplete)
    end
  end

  # Ensure if beta testing tracks are enabled, submissions are also configured
  def beta_release_submissions
    if beta_release_submissions_enabled && beta_release.submissions&.reject(&:marked_for_destruction?).blank?
      errors.add(:base, :beta_releases_are_incomplete)
    end
  end

  def production_valid?
    production_release.present? && !production_release.marked_for_destruction?
  end

  def internal_valid?
    internal_release.present? && !internal_release.marked_for_destruction?
  end

  # beta releases are always present, so we check for submissions in particular for any beta-related validations
  def beta_valid?
    beta_release&.submissions.present? && !beta_release.marked_for_destruction?
  end
end
