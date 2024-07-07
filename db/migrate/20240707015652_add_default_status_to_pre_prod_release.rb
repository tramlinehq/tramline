class AddDefaultStatusToPreProdRelease < ActiveRecord::Migration[7.0]
  def change
    change_column_default :pre_prod_releases, :status, from: nil, to: "created"
  end
end
