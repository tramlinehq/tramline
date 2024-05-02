# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
#  failure_reason          :string
#  name                    :string
#  prepared_at             :datetime
#  rejected_at             :datetime
#  status                  :string           not null
#  store_link              :string
#  store_status            :string
#  submitted_at            :datetime
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             indexed
#  release_platform_run_id :uuid             not null, indexed
#
class StoreSubmission < ApplicationRecord
  include AASM
  include Passportable
  include Loggable
  include Displayable

  belongs_to :release_platform_run
  belongs_to :build, optional: true

  delegate :release_metadata, :train, to: :release_platform_run
  delegate :notify!, to: :train
  delegate :version_name, :build_number, to: :build

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

  def notification_params
    release_platform_run
      .notification_params
      .merge(
        {
          project_link: store_link
        }
      )
  end
end
