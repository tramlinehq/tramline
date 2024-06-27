class AddMoreFieldsToStoreSubmissions < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :store_submissions, :sequence_number, :smallint, null: false, default: 0

    remove_check_constraint :store_submissions,
      "production_release_id IS NOT NULL AND pre_prod_release_id IS NULL OR production_release_id IS NULL AND pre_prod_release_id IS NOT NULL",
      name: "only_one_release_present",
      validate: false

    safety_assured do
      remove_belongs_to :store_submissions, :pre_prod_release
      remove_belongs_to :store_submissions, :production_release
    end

    add_reference :store_submissions, :parent_release, polymorphic: true, null: false, index: {algorithm: :concurrently}
  end
end
