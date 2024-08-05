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
class InternalRelease < PreProdRelease
  def finish!(build)
    update!(status: STATES[:finished])
    Coordinators::Signals.build_is_available_for_regression_testing!(build)
  end
end
