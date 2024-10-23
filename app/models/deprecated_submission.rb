# == Schema Information
#
# Table name: store_submissions
#
#  id                      :uuid             not null, primary key
#  approved_at             :datetime
#  config                  :jsonb
#  failure_reason          :string
#  name                    :string
#  parent_release_type     :string           indexed => [parent_release_id]
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
#  parent_release_id       :uuid             indexed => [parent_release_type]
#  release_platform_run_id :uuid             not null, indexed
#
class DeprecatedSubmission < StoreSubmission
  # include Sandboxable
  include Displayable

  STAMPABLE_REASONS = %w[
    triggered
    finished
    failed
  ]

  STATES = {
    created: "created",
    finished: "finished",
    failed: "failed"
  }

  enum :status, STATES

  def provider = DeprecatedProvider.new

  class DeprecatedProvider
    include Displayable

    def to_s
      "deprecated"
    end
  end
end
