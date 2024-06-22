class AddCheckConstraintToStoreSubmissions < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      change_table :store_submissions do |t|
        t.belongs_to :pre_prod_release, null: true, index: true, foreign_key: true, type: :uuid
      end
    end

    add_check_constraint :store_submissions,
                         "production_release_id IS NOT NULL AND pre_prod_release_id IS NULL OR production_release_id IS NULL AND pre_prod_release_id IS NOT NULL",
                         name: "only_one_release_present",
                          validate: false

    # validate_check_constraint :store_submissions, name: "only_one_release_present"

    safety_assured do
      change_table :production_releases do |t|
        t.belongs_to :release_platform_run, null: false, index: true, foreign_key: true, type: :uuid
      end
    end
  end
end
