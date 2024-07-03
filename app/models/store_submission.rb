# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
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
#  submission_config       :jsonb
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
    submission_config["submission_config"]
  end

  def deployment_channel_id
    deployment_channel["id"].to_s
  end

  def staged_rollout?
    submission_config["rollout_config"]["enabled"]
  end

  def auto_rollout?
    submission_config["auto_promote"]
  end

  # FIXME: will be startable as soon as it is created
  def startable?
    build.present?
  end

  def external_link
    store_link || project_link
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
          deployment_channel:,
          deployment_channel_asset_link: public_icon_img,
          deployment_channel_type: provider.to_s.titleize,
          project_link: external_link,
          requires_review: requires_review?
        }
      )
  end

  protected

  def fail_with_error(error)
    elog(error)
    if error.is_a?(Installations::Error)
      if error.reason == :app_review_rejected
        # TODO: Implement this
        fail_with_sync_option!(reason: error.reason)
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
end
