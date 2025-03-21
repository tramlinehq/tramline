class AddUniqueIndexForVersionBumpPrs < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      add_index :pull_requests, [:release_id, :phase],
                unique: true,
                where: "phase = 'version_bump' AND state = 'open'",
                algorithm: :concurrently
    end
  end
end
