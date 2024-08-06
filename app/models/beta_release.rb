# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                         :bigint           not null, primary key
#  config                     :jsonb            not null
#  status                     :string           default("created"), not null
#  tester_notes               :text
#  type                       :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  commit_id                  :uuid             indexed
#  parent_internal_release_id :bigint           indexed
#  previous_id                :bigint           indexed
#  release_platform_run_id    :uuid             not null, indexed
#
class BetaRelease < PreProdRelease
  belongs_to :parent_internal_release, class_name: "InternalRelease", optional: true

  def finish!
    with_lock do
      update!(status: STATES[:finished])
      Coordinators::Signals.beta_release_is_available!(build)
    end
  end

  def new_build_available?
    return unless carried_over?
    release_platform_run.latest_internal_release(finished: true) != parent_internal_release
  end

  def carried_over?
    parent_internal_release.present?
  end

  def new_commit_available?
    return if carried_over?
    release_platform_run.last_commit != commit
  end
end
