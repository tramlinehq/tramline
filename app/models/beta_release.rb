# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                      :bigint           not null, primary key
#  config                  :jsonb            not null
#  status                  :string           default("created"), not null
#  tester_notes            :text
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commit_id               :uuid             indexed
#  previous_id             :bigint           indexed
#  release_platform_run_id :uuid             not null, indexed
#
class BetaRelease < PreProdRelease
  def finish!(build)
    update!(status: STATES[:finished])
    Coordinators::Signals.beta_release_is_available!(build)
  end
end
