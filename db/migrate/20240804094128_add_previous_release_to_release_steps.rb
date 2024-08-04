class AddPreviousReleaseToReleaseSteps < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      add_reference :pre_prod_releases, :previous, foreign_key: {to_table: :pre_prod_releases}, index: true, type: :bigint
      add_reference :production_releases, :previous, foreign_key: {to_table: :production_releases}, index: true, type: :bigint
    end
  end
end
