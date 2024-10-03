# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                         :uuid             not null, primary key
#  config                     :jsonb            not null
#  status                     :string           default("created"), not null
#  tester_notes               :text
#  type                       :string           not null, indexed => [release_platform_run_id, commit_id]
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  commit_id                  :uuid             not null, indexed => [release_platform_run_id, type], indexed
#  parent_internal_release_id :uuid             indexed
#  previous_id                :uuid             indexed
#  release_platform_run_id    :uuid             not null, indexed => [commit_id, type], indexed
#
class InternalRelease < PreProdRelease
  STAMPABLE_REASONS = %w[created finished failed]

  def finish!
    with_lock do
      update!(status: STATES[:finished])
      event_stamp!(reason: :finished, kind: :success, data: stamp_data)
      notify_with_snippet!(
        "Internal release has been finished!",
        :internal_release_finished,
        notification_params,
        tester_notes,
        "Tester notes:"
      )
      Signal.internal_release_finished!(build)
    end
  end

  def tester_notes? = true

  def release_notes? = false
end
