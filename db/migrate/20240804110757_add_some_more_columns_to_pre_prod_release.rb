class AddSomeMoreColumnsToPreProdRelease < ActiveRecord::Migration[7.0]
  def change
    safety_assured { add_belongs_to :pre_prod_releases, :commit, index: true, foreign_key: true, type: :uuid }
    add_column :pre_prod_releases, :tester_notes, :text
  end
end
