# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
#  config                  :jsonb
#  failure_reason          :string
#  name                    :string
#  parent_release_type     :string           not null, indexed => [parent_release_id]
#  prepared_at             :datetime
#  rejected_at             :datetime
#  sequence_number         :integer          default(0), not null, indexed
#  status                  :string           not null
#  store_link              :string
#  store_release           :jsonb
#  store_status            :string
#  submitted_at            :datetime
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             not null, indexed
#  parent_release_id       :bigint           not null, indexed => [parent_release_type]
#  release_platform_run_id :uuid             not null, indexed
#
class StoreSubmission < ApplicationRecord
  include AASM
  include Passportable
  include Loggable
  include Displayable

  has_one :store_rollout, dependent: :destroy
  belongs_to :release_platform_run
  belongs_to :parent_release, polymorphic: true
  belongs_to :build

  delegate :release_metadatum, :train, :release, :app, :platform, to: :release_platform_run
  delegate :project_link, :public_icon_img, to: :provider, allow_nil: true
  delegate :notify!, to: :train
  delegate :version_name, :build_number, to: :build

  def deployment_channel
    conf.submission_config
  end

  delegate :name, to: :deployment_channel, prefix: true

  def triggerable?
    created? && active_release?
  end

  def deployment_channel_id
    conf.submission_config.id.to_s
  end

  def staged_rollout?
    conf.rollout_config.enabled
  end

  def auto_rollout? = !parent_release.production?

  def external_link
    store_link || project_link
  end

  def attach_build(build)
    update!(build:)
  end

  def self.create_and_trigger!(parent_release, submission_config, build)
    auto_promote = submission_config.auto_promote?
    auto_promote = parent_release.conf.auto_promote? if auto_promote.nil?
    release_platform_run = parent_release.release_platform_run
    sequence_number = submission_config.number
    config = submission_config.to_h

    submission = create!(parent_release:, release_platform_run:, build:, sequence_number:, config:)
    submission.trigger! if auto_promote
  end

  def notification_params
    release_platform_run
      .notification_params
      .merge(
        {
          is_staged_rollout_deployment: staged_rollout?,
          is_production_channel: true,
          is_app_store_production: is_a?(AppStoreSubmission),
          is_play_store_production: is_a?(PlayStoreSubmission),
          deployment_channel: conf.submission_config,
          deployment_channel_asset_link: public_icon_img,
          deployment_channel_type: provider.to_s.titleize,
          project_link: external_link,
          requires_review: requires_review?
        }
      )
  end

  def active_release?
    parent_release.active?
  end

  protected

  def fail_with_error(error)
    elog(error)
    if error.is_a?(Installations::Error)
      if error.reason == :app_review_rejected
        fail_with_sync_option!(reason: error.reason) # TODO: Implement this
      else
        fail!(reason: error.reason)
      end
    else
      fail!
    end
  end

  def set_failure_reason(args = nil)
    self.failure_reason = args&.fetch(:reason, :unknown_failure)
  end

  def set_prepared_at!
    update! prepared_at: Time.current
  end

  def set_submitted_at!
    update! submitted_at: Time.current
  end

  def set_approved_at!
    update! approved_at: Time.current
  end

  def set_rejected_at!
    update! rejected_at: Time.current
  end

  def stamp_data
    {
      version: version_name,
      build_number: build_number
    }
  end

  def conf = ReleaseConfig::Platform::Submission.new(config)
end
