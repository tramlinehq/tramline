# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                      :bigint           not null, primary key
#  status                  :string           not null
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  release_platform_run_id :uuid             not null, indexed
#
class InternalRelease < PreProdRelease
end
