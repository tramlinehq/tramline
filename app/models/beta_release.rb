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
class BetaRelease < PreProdRelease
  STAMPABLE_REASONS = %w[created finished failed]

  def tester_notes? = false

  def release_notes? = true

  def rollout_complete!(submission)
    notify_with_snippet!(
      "Beta release finished",
      :beta_submission_finished,
      submission.notification_params,
      tester_notes,
      "Changes since last release"
    )
    super
  end

  def finish!
    with_lock do
      update!(status: STATES[:finished])
      event_stamp!(reason: :finished, kind: :success, data: stamp_data)
      Signal.beta_release_is_finished!(build)
    end
  end

  def new_commit_available?
    return unless release_platform_run.on_track?
    release_platform_run.last_commit != commit
  end
end
