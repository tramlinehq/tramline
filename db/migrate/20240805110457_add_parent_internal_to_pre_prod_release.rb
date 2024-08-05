class AddParentInternalToPreProdRelease < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      add_reference :pre_prod_releases, :parent_internal_release, foreign_key: {to_table: :pre_prod_releases}, type: :bigint, index: true
    end
  end
end
