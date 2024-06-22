# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
#  deployment_channel      :jsonb
#  failure_reason          :string
#  name                    :string
#  prepared_at             :datetime
#  rejected_at             :datetime
#  status                  :string           not null
#  store_link              :string
#  store_release           :jsonb
#  store_status            :string
#  submitted_at            :datetime
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             indexed
#  pre_prod_release_id     :uuid             indexed
#  production_release_id   :bigint           indexed
#  release_platform_run_id :uuid             not null, indexed
#
class StoreSubmission < ApplicationRecord
  include AASM
  include Passportable
  include Loggable
  include Displayable

  has_one :store_rollout
  belongs_to :release_platform_run
  belongs_to :production_release, optional: true
  belongs_to :pre_prod_releases, optional: true

  delegate :release_metadatum, :train, :release, to: :release_platform_run
  delegate :notify!, to: :train
  delegate :version_name, :build_number, to: :build
  delegate :project_link, :public_icon_img, to: :provider

  validates :only_one_release_present

  STATES = {
    created: "created",
    preparing: "preparing",
    prepared: "prepared",
    failed_prepare: "failed_prepare",
    review_failed: "review_failed",
    approved: "approved",
    failed: "failed"
  }

  def build
    pre_production_release&.build || production_release&.build
  end

  def attach_build!(build)
    self.build = build
    save!
  end

  def startable?
    build.present?
  end

  def provider
    release_platform_run.store_provider
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
          requires_review: requires_review?,
        }
      )
  end

  protected

  def fail_with_error(error)
    elog(error)
    if error.is_a?(Installations::Error)
      if error.reason == :app_review_rejected
        fail_with_sync_option!(reason: error.reason)
      else
        fail!(reason: error.reason)
      end
    else
      fail!
    end
  end

  def set_reason(args = nil)
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

  def only_one_release_present
    if production_release.present? && pre_production_release.present?
      errors.add(:base, "Only one release can be present at a time")
    elsif production_release.blank? && pre_production_release.blank?
      errors.add(:base, "At least one release should be present")
    end
  end
end
