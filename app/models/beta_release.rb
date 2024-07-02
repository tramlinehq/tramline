# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                      :bigint           not null, primary key
#  config                  :jsonb            not null
#  status                  :string           not null
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  release_platform_run_id :uuid             not null, indexed
#
class BetaRelease < PreProdRelease
  def finish!
    update!(status: STATES[:finished])
    Coordinators::Signals.beta_release_is_available!(build)
  end
end
